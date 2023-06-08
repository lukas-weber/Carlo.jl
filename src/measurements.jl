mutable struct Measurements{T<:AbstractFloat}
    default_bin_size::Int64
    observables::Dict{Symbol,Observable{T}}
end

Measurements{T}(default_bin_size::Integer) where {T} =
    Measurements{T}(default_bin_size, Dict())

function add_sample!(meas::Measurements, obsname::Symbol, value)
    if !haskey(meas.observables, obsname)
        register_observable!(meas, obsname, meas.default_bin_size, length(value))
    end

    add_sample!(meas.observables[obsname], value)
    return nothing
end

function register_observable!(
    meas::Measurements{T},
    obsname::Symbol,
    bin_length::Integer,
    vector_length::Integer,
) where {T}
    if haskey(meas.observables, obsname)
        error("Observable '$(obsname)' already exists.")
    end

    meas.observables[obsname] = Observable{T}(bin_length, vector_length)
    return nothing
end

function write_measurements!(meas::Measurements, out::HDF5.Group)
    for (name, obs) in meas.observables
        if has_complete_bins(obs)
            write_measurements!(obs, create_absent_group(out, String(name)))
        end
    end
    return nothing
end

function write_checkpoint(meas::Measurements, out::HDF5.Group)
    out["default_bin_size"] = meas.default_bin_size

    for (name, obs) in meas.observables
        write_checkpoint(obs, create_group(out, "observables/$(name)"))
    end
    return nothing
end

function read_checkpoint(::Type{Measurements{T}}, in::HDF5.Group) where {T}
    default_bin_size = read(in, "default_bin_size")

    observables = Dict{Symbol,Observable{T}}()
    for obsname in keys(in["observables"])
        observables[Symbol(obsname)] =
            read_checkpoint(Observable{T}, in["observables/$(obsname)"])
    end

    return Measurements{T}(default_bin_size, observables)
end
