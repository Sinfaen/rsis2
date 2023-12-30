module rsiswrap

using Logging
using TOML

"""
represents a single field within a rust struct
"""
struct Port
    name :: String
    type :: String # Julia type
    base_type :: String # Julia type, stripped of generics
    dimension :: Tuple # empty if scalar, contains dimensions otherwise
    units :: Any
    default :: Any
    
    # quick access for templates
    dict_info :: Tuple # empty if not, contains two types if true
    is_scalar :: Bool
    is_vector :: Bool
    is_arr1 :: Bool
    is_user_struct :: Bool
    is_generic :: Bool

    function Port(name::String, type::String, dimension::Tuple, units::Any, default::Any, is_user::Bool, is_gtype::Bool)
        toks = _type_tokens(type)
        base_type = toks[1]
        is_dict = ()
        if length(toks) > 1 # generic struct or Dict
            # only handles 1 generic
            if base_type == "Dict"
                if length(toks) != 3
                    throw(ErrorException("Unable to parse $(type) as a dictionary"))
                end
                is_dict = (toks[2], toks[3])
            end
        end
        is_scalar = isempty(dimension)
        is_vec = (dimension == (-1,))
        is_arr1 = length(dimension) == 1 && !is_vec
        new(name, type, base_type, dimension, units, default, is_dict, is_scalar, is_vec, is_arr1, is_user, is_gtype)
    end
end

"""
represents <T> in a rust generic
"""
struct GenericType
    options :: Vector{String} # all allowed rsis types
    default :: String         # default type out of allowed
end

"""
represents a rust struct
"""
mutable struct RsisStruct
    name :: String
    desc :: String
    fields :: Vector{Port}

    # map type name, e.g. `T` to the struct
    generics :: Dict{String, GenericType}

    function RsisStruct(name :: String, desc :: String)
        new(name, desc, Vector{Port}(), Dict{String, GenericType}())
    end
end

function is_generic(obj::RsisStruct) :: Bool
    return length(obj.generics) > 0
end

mutable struct Context
    definedstructs :: Set{String}
    structinfo :: Dict{String, RsisStruct}
    name :: String
    tags :: Dict{String, String}
    function Context()
        new(Set{String}(), Dict{String, RsisStruct}(), "", Dict{String, String}())
    end
end

struct Target
    name :: String
    path :: String
    desc :: String
    num  :: Int
end

_primitive_types = Dict{String, DataType}([
    "Bool" => Bool,
    "Char" => Char,
    "String" => String,
    "Int" => Int,
    "Int8" => Int8,
    "Int16" => Int16,
    "Int32" => Int32,
    "Int64" => Int64,
    "UInt"  => UInt,
    "UInt8" => UInt8,
    "UInt16" => UInt16,
    "UInt32" => UInt32,
    "UInt64" => UInt64,
    "Float32" => Float32,
    "Float64" => Float64,
    "ComplexF32" => ComplexF32,
    "ComplexF64" => ComplexF64,
])

"""
Splits typenames into tokens. If only 1 element, regular type.
If multiple, generic is detected
"""
function _type_tokens(txt::String) :: Vector{String}
    tokens = split(txt, r"[\{,\}]")
    return [strip(t) for t in tokens if !isempty(t)]
end

function rsis_primitive_type(type :: String) :: DataType
    global _primitive_types
    if haskey(_primitive_types, type)
        return _primitive_types[type]
    end
    # this is not a scalar/array type, assuming a Dict
    reg = r"^Dict{(.*),(.*)}$"
    if !occursin(reg, type)
        return Nothing
    end
    m = match(reg, type)
    if haskey(_primitive_types, m[1]) && haskey(_primitive_types, m[2])
        return Dict{_primitive_types[m[1]], _primitive_types[m[2]]}
    else
        return Nothing
    end
end

function find_targets(addl_paths :: Vector{String} = Vector{String}() ) :: Dict{String, Target}
    default_path = joinpath(pwd(), "templates")
    if isdir(default_path)
        paths = [default_path; addl_paths]
    else
        paths = addl_paths
    end
    targets = Dict{String, Target}()

    for path = paths
        for file = readdir(path)
            (name, ext) = splitext(file)
            if ext == ".toml"
                fullpath = joinpath(path, file)
                data = TOML.parsefile(fullpath)
                if !haskey(data, "rsiswrap")
                    continue
                end
                if !haskey(data, "desc")
                    @warn "Excluding target $(file) due to missing description"
                    continue
                end
                if !haskey(data, "template")
                    @warn "Excluding target $(file) as it defines no templates"
                    continue
                end
                num_templates = length(data["template"])
                targets[name] = Target(name, fullpath, data["desc"], num_templates)
            end
        end
    end
    return targets
end

function parse_value(data :: Any, etype :: DataType, dims :: Tuple) :: Any
    if isempty(dims) # scalar value
        if etype <: Complex
            if isa(data, Vector) && length(data) == 2
                try
                    return etype(data[1], data[2])
                catch e
                    @error "Failed to create complex value from: $(data)"
                    throw(e)
                end
            end
        else
            # surprisingly this also works for the Dict stuff
            try
                return etype(data)
            catch e
                @error "Failed to create $(etype) from $(data)"
                throw(e)
            end
        end
    else # ndarray
        if !isa(data, Vector)
            throw(ErrorException("Unable to create array values from provided"))
        end
        if dims == (-1,)
            # variable length array
            return [parse_value(data[i], etype, ()) for i = eachindex(data)]
        elseif length(dims) == 1
            # 1D array
            if length(data) != dims[1]
                throw(ErrorException("Array length of $(length(data)) does not match expected: $(dims[1])"))
            end
            return [parse_value(data[i], etype, ()) for i = eachindex(data)]
        else
            # 2D+ matrix
            if length(data) != dims[1]
                throw(ErrorException("Array length of $(length(data)) does not match expected: $(dims[1]). More axes"))
            end
            # I think this means a lot of copying?
            val = zeros(etype, dims)
            for i = 1:dims[1]
                val[i,:] = parse_value(data[i], etype, dims[2:end])
            end
            return val
        end
    end
end

function parse_field(ctxt :: Context, str :: RsisStruct, data :: Dict)
    for key = ["name", "type"]
        if !haskey(data, key)
            throw(ErrorException("Field does not define $(key)"))
        end
    end
    name = data["name"]
    # optional dimension handling
    if haskey(data, "dims")
        for d in data["dims"]
            if !(d isa Int)
                throw(ErrorException("Invalid dimension"))
            end
            if d < -1
                throw(ErrorException("Invalid dimension: $(d)"))
            end
        end
        dims = Tuple(data["dims"])
    else
        dims = ()
    end
    # type handling. needs the dimensional information here
    toks = _type_tokens(data["type"])
    is_generic = length(toks) > 1
    base_type = toks[1]
    if is_generic
        if base_type in ctxt.definedstructs
            default = nothing # user defined generic struct
        elseif base_type == "Dict"
            etype = rsis_primitive_type(data["type"])
            default = haskey(data, "value") ? data["value"] : Dict()
        else
            throw(ErrorException("Unable to identify $(base_type) as target for generic"))
        end
    else
        if base_type in ctxt.definedstructs
            default = nothing # user defined struct
        elseif haskey(str.generics, base_type)
            etype = rsis_primitive_type("failure")
            # we have to let the rust compiler figure out if this is valid
            if !haskey(data, "value")
                throw(ErrorException("Missing `value`"))
            end
            default = data["value"]
        else
            # regular value
            etype = rsis_primitive_type(base_type)
            if !haskey(data, "value")
                throw(ErrorException("Missing `value`"))
            end
            try
                default = parse_value(data["value"], etype, dims)
            catch e
                @error "Failed to parse value for [$(name)]"
                throw(e)
            end
            if etype == Nothing
                throw(ErrorException("Failed to recognize: $(data["type"])"))
            end
        end
    end
    # optional units. TODO unitful integration
    units = get(data, "units", "")

    # tag handling
    if haskey(data, "tag")
        tagname = data["tag"]
        if haskey(ctxt.tags, tagname)
            throw(ErrorException("Struct $(name) is tagged with [$(tagname)] but $(ctxt.tags[tagname]) is already marked"))
        end
        ctxt.tags[tagname] = name
    end

    push!(str.fields, Port(name, data["type"], Tuple(dims), units, default, base_type in ctxt.definedstructs, haskey(str.generics, base_type)))
end

function parse_generic(ctxt :: Context, str::RsisStruct, data::Dict)
    for val in ["name", "default"]
        if !haskey(data, val)
            throw(ErrorException("Missing `$(val)` key in generic definition"))
        end
        if !isa(data[val], String)
            throw(ErrorException("Generic `$(val)` must be a string"))
        end
    end
    name = data["name"]
    opts = haskey(data, "options") ? data["options"] : Vector{String}()
    str.generics[name] = GenericType(opts, data["default"])
end

function parse_struct(ctxt :: Context, name::String, desc::String, data :: Dict)
    tbl = RsisStruct(name, desc)
    if !haskey(data, "fields")
        throw(ErrorException("`fields` key not found in [$(name)]"))
    end
    if haskey(data, "generic")
        if !isa(data["generic"], AbstractArray)
            throw(ErrorException("`generic` key is not an array"))
        end
        for obj in data["generic"]
            parse_generic(ctxt, tbl, obj)
        end
    end
    for dat in data["fields"]
        # field parsing
        parse_field(ctxt, tbl, dat)
    end
    ctxt.structinfo[name] = tbl
end

"""
Parses an IDL and returns a RSISContext

Generic specialization specified with `gen_spec` will be applied.
"""
function parse_idl(input_file :: String) :: Context
    if !isabspath(input_file)
        input_file = abspath(input_file)
    end
    if !isfile(input_file)
        throw(ErrorException("Failed to locate file $(input_file)"))
    end

    data = TOML.parsefile(input_file)

    # search for required keys
    for key = ["root", "types"]
        if !haskey(data, key)
            throw(ErrorException("$(input_file) does not define root level $(key)"))
        end
    end
    root = data["root"]
    for key = ["name", "desc"]
        if !haskey(root, key)
            throw(ErrorException("$(input_file):[root] does not define required key: [$(key)]"))
        end
    end

    context = Context()
    context.name = root["name"]

    # get a full list of just the defined types ahead of time
    structdefines = data["types"]
    for (key, value) in structdefines
        if !(value isa Dict)
            @warn "Ignoring $(key)"
            continue
        end
        push!(context.definedstructs, key)
    end

    # now parse each type, ensuring that everything is defined
    for (key, value) in structdefines
        if value isa Dict
            parse_struct(context, key, "", value)
        end
    end

    return context
end

function generate_target(target::Target, ctxt::Context, output_folder::String)
    targetdir = dirname(target.path)
    targetinfo = TOML.parsefile(target.path)

    for temp in targetinfo["template"]
        if !haskey(temp, "file")
            throw(ErrorException("Target $(target.name) has a template with a missing `file` key"))
        end
        if !haskey(temp, "filename")
            throw(ErrorException("Target $(target.name) has a template with a missing `filename` key"))
        end
        infilepath = joinpath(targetdir, temp["file"])

        # now we can get down to business
        afunc = evalfile(infilepath)
        init = Dict("base_name" => ctxt.name, "ctxt" => ctxt)

        # output to file!
        outfilepath = joinpath(output_folder, replace(temp["filename"], "*" => ctxt.name))
        iob = IOBuffer()
        Base.invokelatest(afunc, init, iob)
        open(outfilepath, "w") do io
            write(io, take!(iob))
        end
    end
end

end

using .rsiswrap
using ArgParse
function main()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--include", "-i"
            help = "Additional folders to search for target files"
        "--discovery", "-d"
            help = "List available targets"
            action = :store_true
        "--target", "-t"
            help = "Target to use"
            default = "rsis"
        "--output", "-o"
            help = "(Optional) file to place autogenerated files"
            default = ""
        "--validate"
            help = "Only validate the IDL"
            action = :store_true
        "file"
            help = "TOML files defining model interfaces"
    end
    parsed_args = parse_args(ARGS, s)
    
    all_targets = rsiswrap.find_targets()
    if parsed_args["discovery"]
        @info "Available targets: $(length(all_targets))"
        for (name, target) in all_targets
            println("- $(name) > $(target.num) output(s)")
            println("   - $(target.path)")
        end
        return
    end

    ctxt = rsiswrap.parse_idl(parsed_args["file"])
    if parsed_args["validate"]
        @info "$(length(ctxt.definedstructs)) structs defined"
        @info "Validation Successful"
        return
    end

    if !haskey(all_targets, parsed_args["target"])
        @error "Unknown target $(parsed_args["target"])"
        return
    end
    output_folder = parsed_args["output"]
    if isempty(output_folder)
        output_folder = joinpath(dirname(parsed_args["file"]))
    end
    output_base = splitext(basename(parsed_args["file"]))[1]

    rsiswrap.generate_target(all_targets[parsed_args["target"]], ctxt, output_folder)
    
    @info "Generation Successful"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
