"""
Real-Time Simulation Scheduler Framework

Getting Started:
- Generate a new project with `newproject`, or load an existing with `loadproject`
"""
module rsis

function __version__()
    return "0.2.0"
end

using Unitful, TOML
using DataFrames

include("scenario.jl")
using .scenario
export projectinfo, issceneloaded, newscene, newscene_args, loadscene

include("project.jl")
using .project
export isprojectloaded, getprojectdirectory, loadproject, unloadproject
export generate_interface, compile_model

include("generate.jl")
using .generate
export autogenerate_scene

function __init__()
    @info "Welcome to RSIS $(__version__())"
    if isfile("rsisproject.toml")
        loadproject()
    end
end

end # module rsis
