module scenario

using REPL.TerminalMenus
using ..TOML
using ..Unitful

export getscene, projectinfo, setproject, ProjectInfo
export issceneloaded, newscene, newscene_args, loadscene
export isprojectloaded, searchpath, addpath!, restorepath
export ProjectType, Model, Container

@enum ProjectType begin
    Model = 1
    Container = 2
end

mutable struct ProjectInfo
    # printed in REPL
    loaded::Bool
    directory::String
    name::String
    desc::String
    type::ProjectType

    # not printed to REPL
    scene_loaded::Bool
    autocode_path::String
    paths::Vector{String} # file path system
    function ProjectInfo()
        new(false, "", "", "", Model, false, "", ["."])
    end
    function ProjectInfo(l::Bool, d::String, n::String, d2::String, t::ProjectType, sl::Bool, ap::String)
        new(l, d, n, d2, t, sl, ap, ["."])
    end
end
Base.show(io::IO, p::ProjectInfo) = print(io,
    """
    :loaded    = $(p.loaded)
    :directory = "$(p.directory)"
    :name      = "$(p.name)"
    :desc      = "$(p.desc)"
    :type      = "$(p.type)"
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
    spec   :: Float64 # scenario defined frequency
end

mutable struct ThreadInfo
    ind :: Int
    freq :: Float64
    schedule :: Vector{ModelCallback}
    function ThreadInfo(i::Int, f::Float64)
        new(i, f, Vector{ModelCallback}())
    end
end

mutable struct Scenario
    name :: String
    scheduler :: String

    threads :: Vector{ThreadInfo}
    modules :: Set{String} # model libraries

    stoptime :: Float64 # seconds
    function Scenario()
        new("", "", Vector{ThreadInfo}(), Set{String}(), 0.0)
    end
    function Scenario(n::String, s::String)
        new(n, s, Vector{ThreadInfo}(), Set{String}(), 0.0)
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

"""
    isprojectloaded()
Returns boolean indicating a project has been loaded
"""
function isprojectloaded() :: Bool
    return projectinfo().loaded
end

function addpath!(p::String) :: Nothing
    if !isprojectloaded()
        @error "No project loaded"
    end
    if p in projectinfo().paths
        @warn "Path $(p) already registered"
    else
        push!(projectinfo().paths, p)
    end
    return
end

function searchpath(path::String; all::Bool = false) :: Vector{String}
    paths = Vector{String}()
    for p in projectinfo().paths
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

function restorepath() :: Nothing
    if !isprojectloaded()
        @error "No project loaded"
    end
    projectinfo().paths = Vector{String}()
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
        # TODO implement check on OS
        options = ["sim", "ubuntu"]
        menu = RadioMenu(options, pagesize=4)
        engine = options[request("Choose the scheduler:", menu)]
    end
    newscene_args(name, engine)
end

function _parse_scheduled(data::Dict) :: Tuple{String, ModelCallback}
    for k in ["lib", "name", "freq"]
        if !haskey(data, k)
            @error "Schedule definition missing [$(k)]"
        end
    end
    l = data["lib"]
    if !isa(l, String)
        @error "Scheduled model [lib] is not a string"
    end
    n = data["name"]
    if !isa(n, String)
        @error "Scheduled model [name] is not a string"
    end
    f = data["freq"]
    if !isa(f, Real)
        @error "Scheduled model [freq] is not a number"
    end
    return (l, ModelCallback(n, 1, 0, f))
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
        @error "Missing [scene] table"
    end
    st = data["scene"]
    for key in ["name", "engine"]
        if !haskey(st, key)
            @error "Missing [scene].$(key)"
            return
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
                @error "stoptime parsing failed: $(toks)"
            end
            try
                val = parse(Float64, toks[1])
                unit = uparse(toks[2])
                ns.stoptime = ustrip(u"s", val * unit)
            catch e
                @error "Parsing $(st["stop"]) > $(e)"
            end
        else
            @error "stoptime is not a numeric: $(st["stop"])"
        end
    end

    if !haskey(data, "schedule")
        @error "Missing [schedule] info"
    end
    sched = data["schedule"]
    if typeof(sched) <: AbstractVector
        # single thread
        t = ThreadInfo(0, 0.0)
        for s in sched
            (libname, sinfo) = _parse_scheduled(s)
            push!(ns.modules, libname)
            push!(t.schedule, sinfo)
        end
        push!(ns.threads, t)
    else
        @error "multi-threaded scenarios not supported yet"
        return
    end

    _scene = ns;
    projectinfo().scene_loaded = true
    return
end

end
