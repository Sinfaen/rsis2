module project

using ..TOML
using ..scenario

export loadproject, unloadproject
export generate_interface, compile_model


"""
    loadproject(directory::String = ".")
Load a project, defaulting to the current operating directory.
"""
function loadproject(directory::String = ".") :: Nothing
    _dir = abspath(directory)
    if !isdir(_dir)
        throw(ErrorException("Directory: $(directory) does not exist."))
    end
    cd(_dir)

    if !isfile("rsisproject.toml")
        throw(ErrorException("`rsisproject.toml` not found. `newproject` can be used to regenerate project files"))
    end
    _f = open("rsisproject.toml")
    projectdata = TOML.parse(_f)
    close(_f)
    if !haskey(projectdata, "rsisproject")
        throw(ErrorException("Invalid `rsisproject.toml` file. Key: [rsisproject] not found"))
    end
    dat = projectdata["rsisproject"]
    if !haskey(dat, "name")
        throw(ErrorException("[rsisproject] is missing `name`"))
    end
    ptype = haskey(projectdata, "cargo") ? Model : Container

    autocode_path = joinpath(_dir, "autocode")
    if !isdir(autocode_path)
        mkdir(autocode_path)
    end

    setproject(ProjectInfo(true, _dir, projectdata["rsisproject"]["name"],
        haskey(dat, "desc") ? dat["desc"] : "",
        ptype, false, autocode_path))
    
    if haskey(dat, "filepaths")
        fp = dat["filepaths"]
        if !(typeof(fp) <: AbstractArray)
            @error "[rsisproject].filepaths is not an array type"
        end
        for f in fp
            addpath!(f)
        end
    end
    @info "Loaded RSIS project at $(projectinfo().directory)"
end

"""
    unloadproject()
Exits the current project
"""
function unloadproject()
    if isprojectloaded()
        setproject(ProjectInfo())
        @info "Unloaded RSIS project"
    else
        @error "No RSIS project is loaded"
    end
end

function _idl_path() :: String
    return joinpath(projectinfo().directory, "src", "idl.toml")
end

function _autogen_paths() :: Vector{String}
    n = projectinfo().name
    d = projectinfo().directory
    return [joinpath(d, "src", n * "_interface.rs"),
            joinpath(d, "src", n * "_msgpack.rs")]
end
"""
[NOEXPORT] interfaces_out_of_date()
Returns true if the autogenerated interface files are out of date
w.r.t. the IDL file.
Returns false if no project is loaded.
"""
function interfaces_out_of_date()
    if isprojectloaded()
        idlpath = _idl_path()
        tocheck = _autogen_paths()
        if isfile(idlpath)
            # mtime returns 0.0 for files that don't exist
            return min([mtime(x) for x in tocheck]...) < mtime(idlpath)
        else
            throw(ErrorException("No interface file found"))
        end
    end
    # nothing is out of date, there is no project
    return false
end

function generate_interface()
    if interfaces_out_of_date()
        @info "Generating interface"
    else
        @info "Interface up to date"
    end
end

"""
Compiles the model
"""
function compile_model()
    generate_interface()

    # basic implementation
    @info "Compiling model"
    compile_cmd = `cargo build`
    run(compile_cmd)
end

end