using HDF5
using Random

"""
Holds the LoadLeveller-internal state of the simulation and provides an interface to

- **Random numbers**: the public member `MCContext.rng` is a random number generator (see [rng](@ref))
- **Measurements**: see [`measure!(::MCContext, ::Any, ::Any)`](@ref)
- **Simulation state**: see [`is_thermalized`](@ref)
"""
mutable struct MCContext{RNG<:Random.AbstractRNG}
    sweeps::Int64
    thermalization_sweeps::Int64

    rng::RNG
    measure::Measurements{Float64}
end

"""
    measure!(ctx::MCContext, name::Symbol, value)

Measure a sample for the observable named `name`. The sample `value` may be either a scalar or vector of a float type. 
"""
measure!(ctx::MCContext, name::Symbol, value) = add_sample!(ctx.measure, name, value)

"""
    is_thermalized(ctx::MCContext)::Bool

Returns true if the simulation is thermalized.
"""
is_thermalized(ctx::MCContext) = ctx.sweeps > ctx.thermalization_sweeps

function MCContext{RNG}(parameters::AbstractDict) where {RNG}
    measure = Measurements{Float64}(parameters[:binsize])
    register_observable!(measure, :_ll_checkpoint_read_time, 1, 1)
    register_observable!(measure, :_ll_checkpoint_write_time, 1, 1)


    if haskey(parameters, :seed)
        rng = RNG(parameters[:seed])
    else
        rng = RNG()
    end

    return MCContext(0, parameters[:thermalization], rng, measure)
end


function write_measurements!(ctx::MCContext, meas_file::HDF5.Group)

    write_measurements!(ctx.measure, create_absent_group(meas_file, "observables"))
    # TODO: write version    

    return nothing
end

function write_checkpoint(ctx::MCContext, out::HDF5.Group)
    write_checkpoint(ctx.rng, create_group(out, "random_number_generator"))
    write_checkpoint(ctx.measure, create_group(out, "measurements"))

    out["sweeps"] = ctx.sweeps
    out["thermalization_sweeps"] = ctx.thermalization_sweeps

    return nothing
end

function read_checkpoint(::Type{MCContext{RNG}}, in::HDF5.Group) where {RNG}
    sweeps = read(in, "sweeps")
    therm_sweeps = read(in, "thermalization_sweeps")

    return MCContext(
        sweeps,
        therm_sweeps,
        read_checkpoint(RNG, in["random_number_generator"]),
        read_checkpoint(Measurements{Float64}, in["measurements"]),
    )
end
