using HDF5

"""Helper to create a group inside a HDF5 node but only if it does not already exist."""
function create_absent_group(
    g::Union{HDF5.File,HDF5.Group},
    name::AbstractString,
)::HDF5.Group
    return if haskey(g, name)
        g[name]
    else
        create_group(g, name)
    end
end

"""Helper to create a dataset inside a HDF5 node but only if it does not already exist."""
function create_absent_dataset(
    g::Union{HDF5.File,HDF5.Group},
    name::AbstractString,
    args...;
    kwargs...,
)::HDF5.Dataset
    return if haskey(g, name)
        g[name]
    else
        create_dataset(g, name, args...; kwargs...)
    end
end
