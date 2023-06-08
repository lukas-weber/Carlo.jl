"""
    Version

The version information for both LoadLeveller and the parent module of the AbstractMC implementation that is currently used. It contains both the version of the Julia packages and their directory tree hashes. The hashes are content hashes of the package directories, as provided by the PackageStates package, at the time of execution.
"""
struct Version
    loadleveller_version::String
    loadleveller_hash::String
    mc_package::String
    mc_version::String
    mc_hash::String

    function Version(mc::Type{<:AbstractMC})
        return new(
            string(pkgversion(@__MODULE__)),
            PackageStates.state(@__MODULE__).directory_tree_hash,
            string(parentmodule(mc)),
            string(pkgversion(parentmodule(mc))),
            PackageStates.state(parentmodule(mc)).directory_tree_hash,
        )
    end
end

function write_hdf5(version::Version, group::HDF5.Group)
    for (field, value) in to_dict(version)
        group[field] = value
    end
end

function to_dict(version::Version)
    return Dict(
        string.(fieldnames(typeof(version))) .=>
            getfield.(Ref(version), fieldnames(typeof(version))),
    )
end
