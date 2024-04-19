module scenario

using REPL.TerminalMenus
using ..TOML
using ..Unitful

export getscene, projectinfo, setproject, ProjectInfo
export issceneloaded, newscene, newscene_args, loadscene

mutable struct ProjectInfo
    # printed in REPL
    loaded::Bool
    directory::String
    name::String
    desc::String

    # not printed to REPL
    scene_loaded::Bool
    autocode_path::String
    function ProjectInfo()
        new(false, "", "", "", false, "")
    end
    function ProjectInfo(l::Bool, d::String, n::String, d2::String, sl::Bool, ap::String)
        new(l, d, n, d2, sl, ap)
    end
end
Base.show(io::IO, p::ProjectInfo) = print(io,
    """
    :loaded    = $(p.loaded)
    :directory = "$(p.directory)"
    :name      = "$(p.name)"
    :desc      = "$(p.desc)"
    """)

struct ModuleInfo
    name    :: String
    path    :: String
    isdebug :: Bool
end

struct ModelCallback
    mod    :: String
    freq   :: Int # relative to thread frequency
    offset :: Int
end

mutable struct ThreadInfo
    name :: String
    freq :: Float64
    schedule :: Vector{ModelCallback}
    function ThreadInfo(name::String, f::Float64)
        new(name, f, Vector{ModelCallback}())
    end
end

mutable struct Scenario
    name :: String
    scheduler :: String

    paths   :: Vector{String} # file path system
    threads :: Vector{ThreadInfo}
    modules :: Vector{ModuleInfo} # model libraries

    stoptime :: Float64 # seconds
    function Scenario()
        new("", "", ["."], Vector{ThreadInfo}(), Vector{ModuleInfo}(), 0.0)
    end
    function Scenario(n::String, s::String)
        new(n, s, ["."], Vector{ThreadInfo}(), Vector{ModuleInfo}(), 0.0)
    end
end

# globals
_scene = Scenario()
_current_project = ProjectInfo()

function getscene() :: Scenario
    return _scene
end

"""
    projectinfo() :: ProjectInfo
Returns struct copy containing all current project info
```jldoctest
julia> projectinfo()
:loaded    = true
:directory = "/home/user/Documents/myproj"
:name      = "Test Stand"
:desc      = "Tests hardware interfaces"
```
"""
function projectinfo() :: ProjectInfo
    return _current_project
end

function setproject(p::ProjectInfo) :: Nothing
    global _current_project
    _current_project = p
    return
end

function addpath!(p::String) :: Nothing
    if p in _scene.paths
        @warn "Path $(p) already registered"
    else
        push!(_scene.paths, p)
    end
    return
end

function searchpath(path::String; all::Bool = false) :: Vector{String}
    scene = getscene()
    paths = Vector{String}()
    for p in scene.paths
        gp = joinpath(p, path)
        if isfile(gp)
            push!(paths, gp)
            if !all
                break
            end
        end
    end
    return paths
end

function issceneloaded() :: Bool
    return projectinfo().scene_loaded
end

function newscene_args(name::String, engine::String) :: Nothing
    global _scene
    # check to see if name is taken
    path = searchpath(name * ".toml")
    if length(path) != 0
        throw(ErrorException("Scene with name: $(name) already exists"))
    end
    _scene = Scenario(name, engine)
    _current_project.scene_loaded = true
    @info "Created new scene: $(name)"
end

"""
Creates new scene with terminal interaction
"""
function newscene(name::String = "", engine::String = "") :: Nothing
    if isempty(name)
        print("Enter name for the new scene: ")
        name = String(strip(readline()))
    end
    if isempty(engine)
        # TODO impelement check on OS
        options = ["sim", "ubuntu"]
        menu = RadioMenu(options, pagesize=4)
        engine = options[request("Choose the scheduler:", menu)]
    end
    newscene_args(name, engine)
end

function loadscene(name::String) :: Nothing
    global _scene
    path = searchpath(name)
    if length(path) == 0
        @error "Failed to locate scene: $(name)"
        return
    end

    data = TOML.parsefile(path[1])

    # check data is valid
    if !haskey(data, "scene")
        throw(ErrorException("Missing [scene] table"))
    end
    st = data["scene"]
    for key in ["name", "engine"]
        if !haskey(st, key)
            throw(ErrorException("Missing [scene].$(key)"))
        end
    end
    ns = Scenario(st["name"], st["engine"])
    
    if haskey(st, "stop")
        if typeof(st["stop"]) <: Real
            ns.stoptime = st["stop"]
        elseif typeof(st["stop"]) == String
            # split by space
            txt = strip(st["stop"])
            toks = split(txt, " ")
            if length(toks) != 2
                throw(ErrorException("stoptime parsing failed: $(toks)"))
            end
            try
                val = parse(Float64, toks[1])
                unit = uparse(toks[2])
                ns.stoptime = ustrip(u"s", val * unit)
            catch e
                throw(ErrorException("Parsing $(st["stop"]) > $(e)"))
            end
        else
            throw(ErrorException("stoptime is not a numeric: $(st["stop"])"))
        end
    end
    _scene = ns;
    return
end

end
