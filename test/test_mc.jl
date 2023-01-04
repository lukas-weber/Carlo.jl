import LoadLeveller

struct TestMC <: LoadLeveller.AbstractMC end

TestMC(params::AbstractDict) = TestMC()

LoadLeveller.init!(mc::TestMC, ctx::LoadLeveller.MCContext, params::AbstractDict) = nothing
LoadLeveller.sweep!(mc::TestMC, ctx::LoadLeveller.MCContext) = nothing

function LoadLeveller.measure!(mc::TestMC, ctx::LoadLeveller.MCContext)
    LoadLeveller.measure!(ctx, :test, ctx.sweeps)
end

LoadLeveller.write_checkpoint(mc::TestMC, out::HDF5.Group) = nothing
LoadLeveller.read_checkpoint!(mc::TestMC, in::HDF5.Group) = nothing

LoadLeveller.register_evaluables(
    ::Type{TestMC},
    eval::LoadLeveller.Evaluator,
    params::AbstractDict,
) = nothing
