mutable struct Measurements
    default_bin_size::Int64
    observables::Dict{String,Observable}
end

Measurements(default_bin_size::Integer) = Measurements(default_bin_size, Dict())

function add_sample!(meas::Measurements, obsname::AbstractString, value)
    if !haskey(meas.observables, obsname)
        register_observable!(meas, obsname, default_bin_size, length(value))
    end

    add_sample!(meas.observables[obsname], value)
    return nothing
end

function _is_legal_observable_name(obsname::AbstractString)
    return !occursin("/", obsname) && !occursin(".", obsname)
end

function register_observable!(
    meas::Measurements,
    obsname::AbstractString,
    bin_length::Integer,
    vector_length::Integer,
)
    if !_is_legal_observable_name(obsname)
        error("Illegal observable name '$(obsname)': names must not contain / or .")
    end

    if haskey(meas.observables, obsname)
        error("Observable '$(obsname)' already exists.")
    end

    meas.observables[obsname] = Observable(obsname, bin_length, vector_length)
    return nothing
end

function write_checkpoint!(meas::Measurements, check_file::HDF5.Group)
    check_file["default_bin_size"] = meas.default_bin_size
    
    for (name, obs) in meas.observables
        write_checkpoint!(obs, check_file["observables/$(name)"])
    end
end

function read_checkpoint(::Type{Measurements}, check_file::HDF5.Group)
    default_bin_size = check_file["default_bin_size"]
    
    observables = Dict()
    for obsname in check_file["observables"]
        observables[obsname] = read_checkpoint(Observable, check_file["observable/$(obsname)"])
    end
    
    return Measurements(default_bin_size, observables)
end