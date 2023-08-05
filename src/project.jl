module project

using ..TOML
using ..scenario

export isprojectloaded, getprojectdirectory, loadproject, unloadproject

"""
    isprojectloaded()
Returns boolean indicating a project has been loaded
"""
function isprojectloaded() :: Bool
    return projectinfo().loaded
end

function getprojectdirectory() :: String
    return projectinfo().directory
end


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

    setproject(ProjectInfo(true, _dir, projectdata["rsisproject"]["name"],
        haskey(dat, "desc") ? dat["desc"] : ""))
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

end