using HDF5
using Random

"""
Holds the Carlo-internal state of the simulation and provides an interface to

- **Random numbers**: the public field `MCContext.rng` is a random number generator (see [rng](@ref))
- **Measurements**: see [`measure!(::MCContext, ::Symbol, ::Any)`](@ref)
- **Simulation state**: see [`is_thermalized`](@ref)
"""
mutable struct MCContext{RNG<:Random.AbstractRNG,Measure}
    sweeps::Int64
    thermalization_sweeps::Int64

    rng::RNG
    measure::Measure
end

"""
    measure!(ctx::MCContext, name::Symbol, value)

Measure a sample for the observable named `name`. The sample `value` may be either a scalar or vector of a float type. 
"""
measure!(ctx::MCContext, name::Symbol, value) = add_sample!(ctx.measure, name, value)

"""
    is_thermalized(ctx::MCContext) -> Bool

Returns true if the simulation is thermalized.
"""
is_thermalized(ctx::MCContext) = ctx.sweeps > ctx.thermalization_sweeps

function MCContext{RNG}(parameters::AbstractDict; seed_variation::Integer = 0) where {RNG}
    measure = Measurements(parameters[:binsize])
    register_observable!(measure, :_ll_checkpoint_read_time, 1, ())
    register_observable!(measure, :_ll_checkpoint_write_time, 1, ())

    if haskey(parameters, :seed)
        rng = RNG(parameters[:seed] * (1 + seed_variation))
    else
        rng = RNG()
    end

    return MCContext(Int64(0), Int64(parameters[:thermalization]), rng, measure)
end

"""
    register_observable!(
        ctx::MCContext,
        obsname::Symbol;
        binsize::Integer,
        shape::Tuple{Vararg{Integer}} = (),
        T = Float64
    )

Allows pre-registering an observable named `obsname` with custom `binsize`, fixed dimensions `shape` and type `T`. Usually this is unnecessary: Carlo will simply do it for you when you [`measure!`](@ref) the first sample.

Manual registration allows you, however, to override the internal `binsize` of the observable, which would otherwise be set by the `tm.binsize` task parameter. This is useful, for example, when you want to form the histogram of a specific observable, or when you measure a specific observable less frequently than others.
"""
register_observable!(
    ctx::MCContext,
    obsname::Symbol;
    binsize::Integer,
    shape::Tuple{Vararg{Integer}} = (),
    T::Type{<:Number} = Float64,
) = register_observable!(ctx.measure, obsname, binsize, shape, T)

function write_measurements!(ctx::MCContext, meas_file::HDF5.Group)
    write_measurements!(ctx.measure, create_absent_group(meas_file, "observables"))

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
        read_checkpoint(Measurements, in["measurements"]),
    )
end
