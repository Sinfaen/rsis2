# generates the model interface that is exposed to RSIS
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

    function _type_to_string(x::Any) :: String
        if isa(x, String)
            return "String::from(\"" * x * "\")"
        elseif isa(x, ComplexF32)
            return "Complex32::new($(real(x)), $(imag(x)))"
        elseif isa(x, ComplexF64)
            return "Complex64::new($(real(x)), $(imag(x)))"
        else
            return "$(x)"
        end
    end

    function _write_nd_array(x::Any, type::String, dims::Tuple) :: String
        if length(dims) == 1
            return "[$(join([_type_to_string(y) for y in x], ", "))]"
        else
            # reshape data to a 1d array
            newdata = permutedims(x, reverse(1:ndims(x)))
            compacted = reshape(newdata, 1, :)
            dimtxt = join(["Const<$(d)>" for d in dims], ", ")
            rtype = _typeconvert[type]
            arrstr = "ArrayStorage<$(rtype), $(join(dims, ", "))>"
            return "Matrix::<$(rtype), $(dimtxt), $(arrstr)>::new($(join(compacted, ",")))"
        end
    end

    write(io,
    """
    // Autogenerated from rsiswrap
    #![allow(non_camel_case_types)]
    #![allow(non_snake_case)]
    extern crate num_complex;
    extern crate nalgebra;
    use std::collections::HashMap;
    use num_complex::Complex32;
    use num_complex::Complex64;
    use nalgebra::{SMatrix};
    use nalgebra::dimension::Const;

    """)

    # write out the struct definitions
    for (key, val) in data["ctxt"].structinfo
        write(io, "#[derive(Default, Clone)]\n")
        generictxt = length(val.generics) > 0 ? "<" * join(keys(val.generics), ",") * ">" : ""
        write(io, "pub struct $(key)$(generictxt) {\n")
        for skey in val.fields
            if isempty(skey.dict_info)
                if skey.type in keys(_typeconvert)
                    # primitive type
                    rtype = _typeconvert[skey.type]
                else
                    # user defined type
                    rtype = replace(skey.type, "{" => "<", "}" => ">")
                end
            else
                rtype = "HashMap<$(_typeconvert[skey.dict_info[1]]),$(_typeconvert[skey.dict_info[2]])>"
            end
            if skey.is_scalar
                write(io, "    pub $(skey.name) : $(rtype),\n")
            elseif skey.is_vector
                write(io, "    pub $(skey.name) : Vec<$(rtype)>,\n")
            elseif skey.is_arr1
                write(io, "    pub $(skey.name) : [$(rtype); $(skey.dimension[1])],\n")
            else # ndarray
                dimtxt = join(skey.dimension, ", ")
                write(io, "    pub $(skey.name) : SMatrix<$(rtype), $(dimtxt)>,\n")
            end
        end
        write(io, "}\n")
    end
end
