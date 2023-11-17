module scenario

export getscene, projectinfo, setproject, ProjectInfo

struct ProjectInfo
    loaded::Bool
    directory::String
    name::String
    desc::String
    function ProjectInfo()
        new(false, "", "","")
    end
    function ProjectInfo(l::Bool, d::String, n::String, d2::String)
        new(l, d, n, d2)
    end
end
Base.show(io::IO, p::ProjectInfo) = print(io,
    """
    :loaded    = $(p.loaded)
    :directory = "$(p.directory)"
    :name      = "$(p.name)"
    :desc      = "$(p.desc)"
    """)

struct ModelCallback
    mod    :: String
    freq   :: Int # relative to thread frequency
    offset :: Int
end

mutable struct ThreadInfo
    freq :: Float64
    schedule :: Vector{ModelCallback}
    function ThreadInfo()
        new(1.0, Vector{ModelCallback}())
    end
    function ThreadInfo(f::Float64)
        new(f, Vector{ModelCallback}())
    end
end

mutable struct Scenario
    current_project :: ProjectInfo

    paths :: Vector{String} # file path system
    threads :: Vector{ThreadInfo}
    function Scenario()
        new(ProjectInfo(), Vector{String}(), Vector{ThreadInfo}())
    end
end

# globals
_scene = Scenario()

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
    return _scene.current_project
end

function setproject(p::ProjectInfo) :: Nothing
    _scene.current_project = p
    return
end

function addpath(p::String) :: Nothing
    if p in _scene.paths
        @warn "Path $(p) already registered"
    else
        push!(_scene.paths, p)
    end
    return
end

end
