
use std::collections::{HashMap, BTreeMap, BTreeSet};

#[derive(Clone)]
pub struct Port {
    pub name: String,
    pub typename: String,
    pub base_type: String,
    pub dimension: Vec<i64>,
    pub default: Option<toml::Value>,
    pub specialized: Vec<String>,

    pub is_generic: bool,
    pub is_specialized: bool,
    pub is_struct: bool,
    pub is_ndarray: bool,
}

pub enum RsisGenType {
    MODEL,
    TABLE,
    MESSAGE,
}

#[derive(Clone)]
pub struct GenericType {
    /// all allowed rsis types
    pub options: Vec<String>,
    pub default: String,
}

#[derive(Clone)]
pub struct RsisStruct {
    pub name: String,
    pub desc: String,
    pub fields: Vec<Port>,
    pub import: String,

    pub generics: BTreeMap<String, GenericType>,
    pub is_generic: bool,
    pub is_imported: bool,
}

pub struct Context {
    /// Names of all structs. Post-processed so that struct dependencies in C++ wrappers compile
    pub structs : BTreeSet<String>,
    pub structinfo : HashMap<String, RsisStruct>,
    pub importedstructs: BTreeSet<String>,
    pub name: String,
    pub tags: HashMap<String, String>,

    pub has_ndarray: bool,
    pub imports: BTreeSet<String>,
}
