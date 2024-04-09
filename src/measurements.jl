mutable struct Measurements
    default_bin_size::Int64
    observables::Dict{Symbol,Accumulator}
end

Measurements(default_bin_size::Integer) = Measurements(default_bin_size, Dict())

function add_sample!(meas::Measurements, obsname::Symbol, value)
    if !haskey(meas.observables, obsname)
        register_observable!(
            meas,
            obsname,
            meas.default_bin_size,
            size(value),
            float(eltype(value)),
        )
    end

    add_sample!(
        meas.observables[obsname]::Accumulator{
            float(eltype(value)),
            ndims(value) + 1,
            ndims(value),
        },
        value,
    )
    return nothing
end

Base.isempty(meas::Measurements) = all(isempty.(values(meas.observables)))
has_complete_bins(meas::Measurements) = any(has_complete_bins.(values(meas.observables)))

function register_observable!(
    meas::Measurements,
    obsname::Symbol,
    bin_length::Integer,
    shape::Tuple{Vararg{Integer}},
    T::Type{<:Number} = Float64,
)
    if haskey(meas.observables, obsname)
        error("Accumulator '$obsname' already exists.")
    end

    meas.observables[obsname] = Accumulator{T}(bin_length, shape)
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
        @assert !has_complete_bins(obs)
        write_checkpoint(obs, create_group(out, "observables/$(name)"))
    end
    return nothing
end

function read_checkpoint(::Type{Measurements}, in::HDF5.Group)
    default_bin_size = read(in, "default_bin_size")

    observables = Dict{Symbol,Accumulator}()
    for obsname in keys(in["observables"])
        observables[Symbol(obsname)] =
            read_checkpoint(Accumulator, in["observables/$(obsname)"])
    end

    return Measurements(default_bin_size, observables)
end
