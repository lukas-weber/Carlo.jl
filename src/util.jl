using HDF5
using Dates

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
