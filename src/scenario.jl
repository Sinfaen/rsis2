module scenario

using REPL.TerminalMenus

export getscene, projectinfo, setproject, ProjectInfo
export issceneloaded, newscene, newscene_args

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
    function Scenario()
        new("", "", Vector{String}(), Vector{ThreadInfo}(), Vector{ModuleInfo}())
    end
    function Scenario(n::String, s::String)
        new(n, s, Vector{String}(), Vector{ThreadInfo}(), Vector{ModuleInfo}())
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
    paths = Vector{String}()
    for p in _scene.paths
        gp = joinpath(p, path)
        if isfile(gp)
            append!(paths, gp)
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

function loadscene(name::String)
    path = searchpath(name * ".toml")
    if length(path) == 0
        @error "Failed to locate scene: $(filepath)"
        return
    end
    # load file with TOML
    @info "TODO IMPLEMENT"
end

end
