# generates an optional messagepack interface for loading structures
# from MessagePack. Used in runtime simulations
function render_to_buffer(data::Dict, io::IOBuffer)
    _typeconvert = Dict(
        "Bool" => "bool",
        "Char" => "char",
        "String" => "String",
        "Int" => "i64",
        "Int8" => "i8",
        "Int16" => "i16",
        "Int32" => "i32",
        "UInt" => "u64",
        "UInt8" => "u8",
        "UInt16" => "u16",
        "UInt32" => "u32",
        "UInt64" => "u64",
        "Float32" => "f32",
        "Float64" => "f64",
        "ComplexF32" => "Complex32",
        "ComplexF64" => "Complex64",
    )
    base_name = data["base_name"]
    intf_name = "$(base_name)_interface"

    write(io,
    """
    // Autogenerated from rsiswrap
    #![allow(non_camel_case_types)]
    #![allow(non_snake_case)]
    extern crate num_complex;
    extern crate nalgebra;
    extern crate rmp;
    extern crate rmp_serde;
    use std::collections::HashMap;
    use nalgebra::SMatrix;
    use std::ffi::c_void;
    use rmp_serde::encode::Error;

    use crate::$(intf_name)::*;

    extern crate rmodel;
    use rmodel::*;
    """)

    # write out the decoding
    for (key, val) in data["ctxt"].structinfo
        write(io,
        """
        pub fn $(key)_from_msgpack(obj: &mut $(key), mp: &[u8], ind: &[i32]) -> i32 {
            if ind.len() == 0 { return 1; }
            match ind[0] {
        """)
        ind = 0
        for skey in val.fields
            if skey.type in keys(_typeconvert) || !isempty(skey.dict_info)
                # primitive
                if length(skey.dimension) > 1
                    # SMatrix
        write(io,
        """
                $(ind) => {
                    let data : Vec<$(_typeconvert[skey.type])> = rmp_serde::from_slice(mp).unwrap();
                    if data.len() != $(prod(skey.dimension)) { return 1; }
                    obj.$(skey.name) = SMatrix::from_vec(data);
                    return 0;
                }
        """)
                else
                    # regular primitive
        write(io,
        """
                $(ind) => {
                    obj.$(skey.name) = rmp_serde::from_slice(mp).unwrap();
                    return 0;
                },
        """)
                end
            else
                # user defined type
        write(io,
        """
                $(ind) => return $(skey.type)_from_msgpack(&mut obj.$(skey.name), mp, &ind[1..]),
        """)
            end
            ind = ind + 1
        end
        write(io,
        """
                _ => return 2,
            }
        }
        """)
    end

    # write out the encoding
    for (key, val) in data["ctxt"].structinfo
        write(io,
        """
        pub fn $(key)_to_msgpack(obj: &mut $(key), ind: &[i32]) -> Result<Vec<u8>, Error> {
            if ind.len() == 0 { return Err(Error::Syntax("RSIS > index length is 0".to_string())); }
            match ind[0] {
        """)
        ind = 0
        for skey in val.fields
            if skey.type in keys(_typeconvert) || !isempty(skey.dict_info)
                # primitive
                if length(skey.dimension) > 1
                    # SMatrix
        write(io,
        """
                $(ind) => {
                    rmp_serde::to_vec(&obj.$(skey.name))
                }
        """)
                else
                    # regular primitive
        write(io,
        """
                $(ind) => {
                    rmp_serde::to_vec(&obj.$(skey.name))
                },
        """)
                end
            else
                # user defined type
        write(io,
        """
                $(ind) => {
                    $(skey.type)_to_msgpack(&mut obj.$(skey.name), &ind[1..])
                },
        """)
            end
            ind = ind + 1
        end
        write(io,
        """
                _ => return Err(Error::Syntax("RSIS > index exceeded length".to_string())),
            }
        }
        """)
    end

    # write metadata documentation interface

    # write out the constructor and box function
    root = data["ctxt"].name
    write(io,
    """
    impl $(root) {
        pub fn new() -> Self {
            Default::default()
        }
    }

    #[no_mangle]
    pub extern "C" fn $(root)_new() -> *mut c_void {
        let obj : Box<Box<dyn RModel + Send>> = Box::new(Box::new($(root)::new()));
        Box::into_raw(obj) as *mut Box<dyn RModel + Send> as *mut c_void
    }
    """)
end
