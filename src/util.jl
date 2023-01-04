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

"""Parse a duration of the format `[[hours:]minutes]:seconds`."""
function parse_duration(duration::AbstractString)::Dates.CompoundPeriod
    m = match(r"^(((?<hours>\d+):)?(?<minutes>\d+):)?(?<seconds>\d+)$", duration)
    if isnothing(m)
        error("$duration does not match [[HH:]MM:]SS")
    end

    conv(period, x) =
        isnothing(x) ? Dates.Second(0) : convert(Dates.Second, period(parse(Int32, x)))
    return conv(Dates.Hour, m[:hours]) +
           conv(Dates.Minute, m[:minutes]) +
           conv(Dates.Second, m[:seconds])
end

parse_duration(duration::Dates.Period) = duration
