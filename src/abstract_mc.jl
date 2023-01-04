"Your Monte Carlo algorithm type should inherit from this and provide the methods below"
abstract type AbstractMC end

macro stub(func::Expr)
    return :(
        $func = error("AbstractMC interface not implemented for MC type $(typeof(mc))")
    )
end

@stub init!(mc::AbstractMC, ctx::MCContext, params::AbstractDict)

"Perform one Monte Carlo sweep"
@stub sweep!(mc::AbstractMC, ctx::MCContext)

"Perform a Monte Carlo measurement"
@stub measure!(mc::AbstractMC, ctx::MCContext)

@stub write_checkpoint(mc::AbstractMC, dump_file::HDF5.Group)
@stub read_checkpoint!(mc::AbstractMC, dump_file::HDF5.Group)

@stub register_evaluables(mc::Type{AbstractMC}, eval::Evaluator, params::AbstractDict)
