function pkgversion_or_missing(mod)
    if isdefined(Base, :pkgversion)
        return string(pkgversion(mod))
    end
    return missing
end

"""
    Version

The version information for both `LoadLeveller` and the parent module of the `AbstractMC` implementation that is currently used.
"""
struct Version
    loadleveller_version::Union{Missing,String}
    mc_package::String
    mc_version::Union{Missing,String}

    function Version(mc::Type{<:AbstractMC})
        return new(
            pkgversion_or_missing(@__MODULE__),
            string(parentmodule(mc)),
            pkgversion_or_missing(parentmodule(mc)),
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
