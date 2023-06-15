"""
This type is an interface for implementing your own Monte Carlo algorithm that will be run by LoadLeveller.
"""
abstract type AbstractMC end

macro stub(func::Expr)
    return :(
        $func = error("AbstractMC interface not implemented for MC type $(typeof(mc))")
    )
end

"""
    init!(mc::YourMC, ctx::MCContext, params::AbstractDict)

Executed when a simulation is started from scratch.
"""
@stub init!(mc::AbstractMC, ctx::MCContext, params::AbstractDict)

"""
    sweep!(mc::YourMC, ctx::MCContext)

Perform one Monte Carlo sweep or update to the configuration.

Doing measurements is supported during this step as some algorithms require doing so for efficiency. However you are responsible for checking if the simulation [`is_thermalized`](@ref).
"""
@stub sweep!(mc::AbstractMC, ctx::MCContext)

"""
    measure!(mc::YourMC, ctx::MCContext)

Perform one Monte Carlo measurement.
"""
@stub measure!(mc::AbstractMC, ctx::MCContext)

"""
    write_checkpoint(mc::YourMC, out::HDF5.Group)

Save the complete state of the simulation to `out`.
"""
@stub write_checkpoint(mc::AbstractMC, dump_file::HDF5.Group)

"""
    read_checkpoint!(mc::YourMC, in::HDF5.Group)
    
Read the state of the simulation from `in`.
"""
@stub read_checkpoint!(mc::AbstractMC, dump_file::HDF5.Group)

"""
    register_evaluables(mc::Type{YourMC}, eval::Evaluator, params::AbstractDict)

This function is used to calculate postprocessed quantities from quantities that were measured during the simulation. Common examples are variances or ratios of observables.

See [evaluables](@ref) for more details.
"""
@stub register_evaluables(mc::Type{AbstractMC}, eval::Evaluator, params::AbstractDict)
