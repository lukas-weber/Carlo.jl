
function get_hash_or_missing(mod)
    hash::Union{Missing,String} = missing
    try
        hash = PackageStates.state(mod).directory_tree_hash
    catch e
        if e isa ErrorException
            hash = missing
        else
            throw(e)
        end
    end
    return hash
end

"""
    Version

The version information for both `LoadLeveller` and the parent module of the `AbstractMC` implementation that is currently used. It contains both the version of the Julia packages and their directory tree hashes. The hashes are content hashes of the package directories, as provided by the `PackageStates` package, at the time of execution.
"""
struct Version
    loadleveller_version::String
    loadleveller_hash::Union{Missing,String}
    mc_package::String
    mc_version::String
    mc_hash::Union{Missing,String}

    function Version(mc::Type{<:AbstractMC})
        return new(
            string(pkgversion(@__MODULE__)),
            get_hash_or_missing(@__MODULE__),
            string(parentmodule(mc)),
            string(pkgversion(parentmodule(mc))),
            get_hash_or_missing(parentmodule(mc)),
        )
    end
end

function write_hdf5(version::Version, group::HDF5.Group)
    for (field, value) in to_dict(version)
        if !haskey(group, field)
            group[field] = string(value)
        end
    end
end

function to_dict(version::Version)
    return Dict(
        string.(fieldnames(typeof(version))) .=>
            getfield.(Ref(version), fieldnames(typeof(version))),
    )
end
