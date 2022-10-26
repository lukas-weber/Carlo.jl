mutable struct Measurements
    default_bin_size::Int64
    observables::Dict{String,Observable}

    Measurements(default_bin_size::Integer) = new(default_bin_size, Dict())
end

function add_sample!(meas::Measurements, obsname::AbstractString, value)
    if !haskey(meas.observables, obsname)
        measurement_registerobservable(meas, obsname, default_bin_size, length(value))
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
        error("Illegal observable name '$obsname': names must not contain / or .")
    end

    if haskey(meas.observables, obsname)
        error("Observable '$obsname' already exists.")
    end

    meas.observables[obsname] = Observable(obsname, bin_length, vector_length)
    return nothing
end
