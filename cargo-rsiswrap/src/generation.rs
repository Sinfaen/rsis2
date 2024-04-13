
use askama::Template;

use crate::context::*;

use std::io::Write;
use std::path::PathBuf;
use std::fs::File;
use std::collections::{HashMap, BTreeMap, BTreeSet};

// askama doesn't allow you to do optional templating easily,
// so I'm using various copies of the structs to do what I want

#[derive(Template)]
#[template(path = "interface.rs", escape="none")]
pub struct RustTemplate {
    pub structs : BTreeSet<String>,
    pub structinfo : HashMap<String, RsisStruct>,
    pub name: String,
    pub tags : HashMap<String, String>,
    pub has_ndarray: bool,
    pub imports: BTreeSet<String>,
}


#[derive(Template)]
#[template(path = "interface.hxx", escape="none")]
pub struct CppTemplate {
    pub structs : BTreeSet<String>,
    pub structinfo : HashMap<String, RsisStruct>,
    pub name: String,
    pub tags : HashMap<String, String>,
    pub has_ndarray: bool,
    pub imports: BTreeSet<String>,
}

#[derive(Template)]
#[template(path = "msgpack.rs", escape="none")]
pub struct MsgPackTemplate {
    pub structs : BTreeSet<String>,
    pub structinfo : HashMap<String, RsisStruct>,
    pub name: String,
    pub tags : HashMap<String, String>,
    pub has_ndarray: bool,
    pub imports: BTreeSet<String>,
}

pub fn rust_dimstr(typename: &String, dims: &Vec<i64>) -> String {
    let txtarr: Vec<String> = dims
        .into_iter()
        .map(|i| i.to_string())
        .collect();
    format!("SMatrix<{}, {}>", typename, txtarr.join(","))
}

pub fn rust_to_cpp_type(typename: &String) -> String {
    (match typename.as_str() {
        "u8" => "uint8_t",
        "u16" => "uint16_t",
        "u32" => "uint32_t",
        "u64" => "uint64_t",
        "i8" => "int8_t",
        "i16" => "int16_t",
        "i32" => "int32_t",
        "i64" => "int64_t",
        "String" => "std::string",
        "bool" => "bool",
        "f32" => "float",
        "f64" => "double",
        _ => "void",
    }).to_string()
}

pub fn cpp_dimstr(typename: &String, name: &String, dims: &Vec<i64>) -> String {
    let txtarr: Vec<String> = dims
        .into_iter()
        .map(|i| i.to_string())
        .collect();
    format!("{} {}[{}]", rust_to_cpp_type(typename), name, txtarr.join(","))
}

pub fn generics_join(generics: &BTreeMap<String, GenericType>) -> String {
    let k: Vec<String> = generics.keys().cloned().collect();
    k.join(",")
}
pub fn generics_deserialize(generics: &BTreeMap<String, GenericType>) -> String {
    let keys: Vec<String> = generics.keys().cloned().collect();
    let txt: Vec<String> = keys.into_iter().map(|x| x + ": for <'a> Deserialize<'a>").collect();
    txt.join(",")
}
pub fn join_string(strings: &Vec<String>) -> String {
    strings.join(",")
}

pub fn generate_template(ctxt: &Context, filename: &str, template: &str) -> bool {
    let path = PathBuf::from(filename);
    let dir = path.parent().unwrap();
    let mut txt = "".to_string();
    match template {
        "interface.rs" => {
            let r_int = RustTemplate {
                structs: ctxt.structs.clone(),
                structinfo: ctxt.structinfo.clone(),
                name: ctxt.name.clone(),
                tags: ctxt.tags.clone(),
                has_ndarray: ctxt.has_ndarray,
                imports: ctxt.imports.clone(),
            };
            match r_int.render() {
                Ok(t) => txt = t,
                Err(_e) => return false,
            }
        },
        "interface.hxx" => {
            let cpp_int = CppTemplate {
                structs: ctxt.structs.clone(),
                structinfo: ctxt.structinfo.clone(),
                name: ctxt.name.clone(),
                tags: ctxt.tags.clone(),
                has_ndarray: ctxt.has_ndarray,
                imports: ctxt.imports.clone(),
            };
            match cpp_int.render() {
                Ok(t) => txt = t,
                Err(_e) => return false,
            }
        },
        "interface.cxx" => {
            return false
        },
        "msgpack.rs" => {
            let msp_int = MsgPackTemplate {
                structs: ctxt.structs.clone(),
                structinfo: ctxt.structinfo.clone(),
                name: ctxt.name.clone(),
                tags: ctxt.tags.clone(),
                has_ndarray: ctxt.has_ndarray,
                imports: ctxt.imports.clone(),
            };
            match msp_int.render() {
                Ok(t) => txt = t,
                Err(_e) => return false,
            }
        },
        _ => return false
    }
    let newfilename = format!("{}_{}", ctxt.name, template);
    let newfilepath = dir.join(newfilename);
    let mut ofile = File::create(newfilepath.clone()).unwrap();
    ofile.write_all(txt.as_bytes()).unwrap();
    println!("Generated: {}", newfilepath.to_str().unwrap());
    return true
}
