import LoadLeveller
using HDF5

struct TestMC <: LoadLeveller.AbstractMC end

TestMC(params::AbstractDict) = TestMC()

LoadLeveller.init!(mc::TestMC, ctx::LoadLeveller.MCContext, params::AbstractDict) = nothing
LoadLeveller.sweep!(mc::TestMC, ctx::LoadLeveller.MCContext) = nothing

function LoadLeveller.measure!(mc::TestMC, ctx::LoadLeveller.MCContext)
    LoadLeveller.measure!(ctx, :test, ctx.sweeps)
    LoadLeveller.measure!(ctx, :test2, ctx.sweeps^2)

    return nothing
end

LoadLeveller.write_checkpoint(mc::TestMC, out::HDF5.Group) = nothing
LoadLeveller.read_checkpoint!(mc::TestMC, in::HDF5.Group) = nothing

function LoadLeveller.register_evaluables(
    ::Type{TestMC},
    eval::LoadLeveller.Evaluator,
    params::AbstractDict,
)
    evaluate!((x, y) -> y - x^2, eval, :test4, [:test, :test2])
    evaluate!(x -> x^2, eval, :test5, [:test])

    return nothing
end
