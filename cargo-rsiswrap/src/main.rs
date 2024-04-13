use clap::Parser;
use toml::Table;
use std::fs;
use std::collections::{HashMap, BTreeMap, BTreeSet};

mod context;
use crate::context::*;
mod generation;
use crate::generation::*;
mod predefined;
use crate::predefined::*;

/// parser
#[derive(Parser, Debug)]
#[command(version, about, long_about=None)]
struct Args {
    /// If true, only validate the IDL
    #[arg(long)]
    validate: bool,

    #[arg(short, long)]
    verbose: bool,

    name: String,

    #[arg(long, default_value_t = String::from("interface.rs"))]
    target: String,
}

#[derive(PartialEq, Clone, Copy, Debug)]
enum ValueType {
    BOOLEAN,
    UnsignedInteger,
    SignedInteger,
    FLOATING,
    STRING,
    INVALID,
}

fn get_type_format(name : &str) -> ValueType {
    match name {
        "i8" | "i16" | "i32" | "i64" => ValueType::SignedInteger,
        "u8" | "u16" | "u32" | "u64" => ValueType::UnsignedInteger,
        "f32" | "f64" => ValueType::FLOATING,
        "String" => ValueType::STRING,
        "bool" => ValueType::BOOLEAN,
        _ => ValueType::INVALID
    }
}

fn parse_dimensions(name: &str, data: &toml::Value) -> Result<Vec<i64>, String> {
    let mut dims = vec![];
    match data.as_array() {
        Some(arr) => {
            for (i, val) in arr.iter().enumerate() {
                match val.as_integer() {
                    Some(d) => {
                        if d < 0 && d != -1 {
                            return Err(format!("Field {} [dims][{}] invalid: {}", name, i, d))
                        }
                        dims.push(d);
                    }
                    None => return Err(format!("Field {} [dims][{}] is not an integer", name, i))
                }
            }
        },
        None => return Err(format!("Field {} [dims] is not an array", name))
    }
    Ok(dims)
}

fn validate_value(vtype: &ValueType, val: &toml::Value) -> bool {
    match vtype {
        ValueType::BOOLEAN => {
            return val.is_bool()
        },
        ValueType::SignedInteger => {
            return val.is_integer()
        },
        ValueType::UnsignedInteger => {
            match val.as_integer() {
                Some(v) => {
                    return v >= 0
                },
                None => return false
            }
        },
        ValueType::FLOATING => {
            return val.is_float()
        },
        ValueType::STRING => {
            return val.is_str()
        }
        _ => return false
    }
}

fn validate_default(name: &str, vtype: ValueType, dims: &[i64], data: &toml::Value) -> Result<bool, String> {
    if dims.len() == 0 {
        // scalar
        if data.is_array() {
            return Err(format!("Field {} default is an array for a scalar value", name))
        }
        if !validate_value(&vtype, data) {
            return Err(format!("Field {} default does not match defined type: {:?}", name, vtype))
        }
    } else {
        // ndarray
        match data.as_array() {
            Some(arr) => {
                for el in arr {
                    match validate_default(name, vtype, &dims[1..], el) {
                        Ok(_) => {},
                        Err(e) => return Err(e),
                    }
                }
            },
            None => return Err(format!("Field {} default fails to match dimension", name))
        }
    }
    Ok(true)
}

fn parse_field(ctxt : &mut Context, sd : &mut RsisStruct, data : &toml::Table) -> Result<Port, String> {
    if !data.contains_key("name") {
        return Err("Field does not define [name]".to_string())
    }
    let name = match data["name"].as_str() {
        Some(val) => val.to_string(),
        None => return Err("Field [name] is not a string".to_string())
    };
    if !data.contains_key("type") {
        return Err(format!("Field {} does not define [type]", name))
    }
    let typename = match data["type"].as_str() {
        Some(val) => val.to_string(),
        None => return Err(format!("Field {} [desc] is not a string", name))
    };

    // check if generic is being used first
    let is_generic = sd.generics.contains_key(typename.as_str());
    if !is_generic {
        // otherwise check that the type is defined
        if !ctxt.structs.contains(typename.as_str()) {
            if ctxt.importedstructs.contains(typename.as_str()) {
                let imp = ctxt.structinfo[typename.as_str()].import.clone();
                ctxt.imports.insert(imp);
            } else {
                if get_type_format(typename.as_str()) == ValueType::INVALID {
                    return Err(format!("Field {} has base type [{}], which is undefined", name, typename))
                }
            }
        }
    }

    // check for template instantiation
    let mut specialized = vec![];
    if data.contains_key("generic") {
        match data["generic"].as_array() {
            Some(vals) => {
                for v in vals {
                    match v.as_str() {
                        Some(vtxt) => {
                            specialized.push(vtxt.to_string());
                        },
                        None => return Err(format!("Field {} [generic] contains invalid value", name))
                    }
                }
            },
            None => return Err(format!("Field {} [generic] is not an array", name))
        }
    }
    let is_specialized = specialized.len() != 0;

    // check for predefined struct
    let is_struct = ctxt.structs.contains(typename.as_str());

    let mut dims = vec![];
    if data.contains_key("dims") {
        match parse_dimensions(name.as_str(), &data["dims"]) {
            Ok(val) => dims = val,
            Err(e) => return Err(e),
        }
    }
    let is_ndarray = dims.len() != 0;
    if is_ndarray {
        ctxt.has_ndarray = true;
    }

    if !is_struct {
        if data.contains_key("default") {
            println!("Warning: field {} missing [default]", name);
            if !is_generic {
                let vtype = get_type_format(typename.as_str());
                match validate_default(name.as_str(), vtype, dims.as_slice(), &data["default"]) {
                    Ok(_) => {},
                    Err(e) => return Err(e)
                }
            }
        }
    }

    if data.contains_key("tag") {
        let tag = match data["tag"].as_str() {
            Some(val) => val.to_string(),
            None => return Err(format!("Field {} [tag] is not a string", name))
        };
        if ctxt.tags.contains_key(&tag) {
            return Err(format!("Struct {} already tagged as [{}] ({})", ctxt.tags[&tag], tag, name))
        }
        ctxt.tags.insert(tag, name.clone());
    }

    let p : Port = Port {
        name: name,
        typename: typename,
        dimension: dims,
        base_type: "".to_string(),
        default: None,
        specialized: specialized,
        is_generic: is_generic,
        is_specialized: is_specialized,
        is_struct: is_struct,
        is_ndarray : is_ndarray,
    };
    Ok(p)
}

fn parse_generic(name : String, data : &toml::Table) -> Result<GenericType, String> {
    let mut gen = GenericType {
        options: vec![],
        default: "".to_string(),
    };
    if data.contains_key("options") {
        match data["options"].as_array() {
            Some(val) => {
                for v in val {
                    match v.as_str() {
                        Some(vv) => {
                            gen.options.push(vv.to_string());
                        },
                        None => return Err(format!("Generic [{}] has non-string option", name))
                    }
                }
            },
            None => return Err(format!("Generic [{}] defines options but is not an array", name))
        }
    } else {
        return Err(format!("Generic [{}] missing `options`", name))
    }
    if data.contains_key("default") {
        match data["default"].as_str() {
            Some(def) => {
                let defs = def.to_string();
                if !gen.options.contains(&defs) {
                    return Err(format!("Generic [{}] has default {} which is not included in the defined options", name, defs));
                }
            },
            None => return Err(format!("Generic [{}] `default` is not a string", name))
        }
    } else {
        return Err(format!("Generic [{}] missing [default]", name))
    }
    Ok(gen)
}

fn parse_struct(ctxt : &mut Context, name : String, data : & toml::Table) -> Result<RsisStruct, String> {
    let mut tbl = RsisStruct {
        name: name.clone(),
        desc: "".to_string(),
        fields: Vec::new(),
        import: "".to_string(),
        generics: BTreeMap::new(),
        is_generic: false,
        is_imported: false,
    };

    if data.contains_key("desc") {
        match data["desc"].as_str() {
            Some(val) => tbl.desc = val.to_string(),
            None => return Err(format!("Struct {} defines [desc] but is not a string", name))
        }
    }

    if data.contains_key("generic") {
        match data["generic"].as_table() {
            Some(val) => {
                for (k,v) in val {
                    match v.as_table() {
                        Some(gd) => {
                            match parse_generic(k.to_string(), gd) {
                                Ok(stat) => {
                                    tbl.generics.insert(k.to_string(), stat);
                                },
                                Err(e) => return Err(e),
                            }
                        },
                        None => return Err(format!("Struct {} generic {} is not a table", name, k))
                    }
                }
            },
            None => return Err(format!("Struct {} defines [generic] but is not a table", name))
        }
        tbl.is_generic = true;
    }

    if data.contains_key("fields") {
        match data["fields"].as_array() {
            Some(fields) => {
                for val in fields {
                    if !val.is_table() {
                        return Err(format!("Struct {} [fields] contains a value that is not a table", name))
                    }
                    match parse_field(ctxt, &mut tbl, val.as_table().expect("critical failure")) {
                        Ok(val) => {
                            tbl.fields.push(val);
                        },
                        Err(e)=> {
                            return Err(e)
                        }
                    }
                }
            },
            None => return Err(format!("Struct {} [fields] is not a table", name))
        }
    } else {
        return Err(format!("Struct {} is empty. Did you mean to make a forward define?", name))
    }

    Ok(tbl)
}

fn parse_idl(contents : String) -> Result<Context, String> {
    let data = contents.parse::<Table>().unwrap();

    // check that these tables are unique
    // model, table, message
    let type_check = (data.contains_key("model")   as i32) +
                     (data.contains_key("table")   as i32) +
                     (data.contains_key("message") as i32);
    if type_check != 1 {
        return Err("Exactly one of the following: [model, table, message] must be defined as a top level key".to_string());
    }
    // todo assume model for now
    let mut name = "".to_string();
    if data.contains_key("model") {
        if !data.contains_key("types") || !data["types"].is_table() {
            return Err("Model interface contains no [types] table".to_string())
        }
        let model_ref = data["model"].as_table().unwrap();
        if !model_ref.contains_key("name") || !model_ref["name"].is_str() {
            return Err("Model interface does not properly define a name".to_string())
        }
        name = model_ref["name"].as_str().unwrap().to_string();
    } else if data.contains_key("table") {
        return Err("table is not implemented".to_string());
    } else if data.contains_key("message") {
        return Err("message is not implemented".to_string());
    }
    let mut all_types: BTreeSet<String> = BTreeSet::<String>::new();
    let types = data["types"].as_table().unwrap();

    // todo handle multiple contexts

    // first pass, collect all type names
    for (key, value) in types {
        if all_types.contains(key) {
            return Err(format!("Type: [{}] already defined", key))
        }
        all_types.insert(key.to_string());
    }

    let mut ctxt = Context {
        structs: all_types.clone(),
        structinfo: HashMap::new(),
        importedstructs: BTreeSet::new(),
        name: name.clone(),
        tags: HashMap::new(),
        has_ndarray: false,
        imports: BTreeSet::new(),
    };
    add_predefined_structures(&mut ctxt);

    // get the struct definitions
    for (key, value) in types {
        let data = value.as_table().unwrap();
        match parse_struct(&mut ctxt, key.to_string(), &data) {
            Ok(str) => {
                ctxt.structinfo.insert(key.to_string(), str);
            },
            Err(e) => return Err(e.clone())
        }
    }

    return Ok(ctxt);
}


fn main() -> Result<(), String> {
    let args = Args::parse();

    let file_name = args.name;

    let contents = fs::read_to_string(file_name.clone())
        .expect("Unable to read interface file");

    let mode = if args.validate {
        "Validating"
    } else {
        "Generating"
    }.to_string();

    match args.target.as_str() {
        "interface.rs" | "interface.hxx" | "msgpack.rs" => {},
        _ => {
            return Err("Unsupported target".to_string())
        }
    }


    if args.verbose {
        println!("{}: {}", mode, file_name.clone());
    }
    match parse_idl(contents) {
        Ok(data) => {
            if !args.validate {
                if !generate_template(&data, &file_name, &args.target) {
                    return Err("generation failure".to_string())
                }
            }
            if args.verbose {
                println!("Context: {}", data.name);
                println!("\t{} structs", data.structs.len());
            }
        },
        Err(e) => {
            println!("Failure: {}", e);
            return Err(e)
        }
    }
    return Ok(())
}
