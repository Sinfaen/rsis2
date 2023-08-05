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

mutable struct Scenario
    current_project :: ProjectInfo
    function Scenario()
        new(ProjectInfo())
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

function setproject(p::ProjectInfo)
    _scene.current_project = p
    return
end

end
