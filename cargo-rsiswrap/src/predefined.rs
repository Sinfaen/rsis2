

use std::collections::BTreeMap;

use crate::context::*;

pub fn add_predefined_structures(ctxt: &mut Context) {
    // predefined values go into the structinfo area
    // the structs actually define what get generated

    ctxt.importedstructs.insert("Complex".to_string());
    ctxt.structinfo.insert("Complex".to_string(), RsisStruct {
        name: "Complex".to_string(),
        desc: "num_complex::Complex<T>".to_string(),
        fields: vec![
            Port {
                name: "re".to_string(),
                typename: "T".to_string(),
                base_type: "".to_string(),
                dimension: vec![],
                default: Some(toml::Value::from(0)),
                specialized: vec![],
                is_generic: false,
                is_specialized: false,
                is_struct: false,
                is_ndarray: false,
            },
            Port {
                name: "im".to_string(),
                typename: "T".to_string(),
                base_type: "".to_string(),
                dimension: vec![],
                default: Some(toml::Value::from(0)),
                specialized: vec![],
                is_generic: false,
                is_specialized: false,
                is_struct: false,
                is_ndarray: false,
            },
        ],
        import: "num::complex::Complex".to_string(),
        generics: BTreeMap::from([
            ("T".to_string(), GenericType {
                options: vec!["f32".to_string(), "f64".to_string()],
                default: "f64".to_string(),
            })
        ]),
        is_generic: true,
        is_imported: true,
    });

    ctxt.importedstructs.insert("HashMap".to_string());
    ctxt.structinfo.insert("HashMap".to_string(), RsisStruct{
        name: "HashMap".to_string(),
        desc: "std::collections::HashMap<K, V>".to_string(),
        fields: vec![],
        import: "std::collections::HashMap".to_string(),
        generics: BTreeMap::from([
            ("K".to_string(), GenericType {
                options: vec![],
                default: "f64".to_string(),
            }),
            ("V".to_string(), GenericType {
                options: vec![],
                default: "f64".to_string(),
            })
        ]),
        is_generic: true,
        is_imported: true,
    });
}
