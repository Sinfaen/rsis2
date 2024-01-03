module generate
# handles autogeneration from a configuration to a shared library or executable

using ..scenario
using ..project

export autogenerate_scene

function autogenerate_scene(name::String = "") :: Nothing
    if !isprojectloaded()
        @error "No project is loaded"
        return
    end

    if !isempty(name)
        loadscene(name)
    end
    sc = getscene()

    if !issceneloaded()
        @error "No scene is loaded"
        return
    end
    @info "Generated $(sc.name)"
end

end
