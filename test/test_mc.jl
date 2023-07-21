import LoadLeveller
using HDF5

struct TestMC <: LoadLeveller.AbstractMC end

TestMC(params::AbstractDict) = TestMC()

LoadLeveller.init!(mc::TestMC, ctx::LoadLeveller.MCContext, params::AbstractDict) = nothing
LoadLeveller.sweep!(mc::TestMC, ctx::LoadLeveller.MCContext) = nothing

function LoadLeveller.measure!(mc::TestMC, ctx::LoadLeveller.MCContext)
    LoadLeveller.measure!(ctx, :test, ctx.sweeps)
    LoadLeveller.measure!(ctx, :test2, ctx.sweeps^2)
    LoadLeveller.measure!(ctx, :test_vec, [ctx.sweeps, sin(ctx.sweeps)])

    return nothing
end

LoadLeveller.write_checkpoint(mc::TestMC, out::HDF5.Group) = nothing
LoadLeveller.read_checkpoint!(mc::TestMC, in::HDF5.Group) = nothing

function LoadLeveller.register_evaluables(
    ::Type{TestMC},
    eval::LoadLeveller.Evaluator,
    params::AbstractDict,
)
    evaluate!((x, y) -> y - x^2, eval, :test4, (:test, :test2))
    evaluate!(x -> x^2, eval, :test5, (:test,))
    evaluate!(eval, :test6, (:test_vec,)) do x
        r = zero(x)
        r[1] = x[1]
        return r
    end

    return nothing
end

mutable struct TestParallelRunMC <: LoadLeveller.AbstractMC
    state::Float64
    try_measure_on_nonroot::Bool
end

TestParallelRunMC(params::AbstractDict) = TestParallelRunMC(0, false)

function LoadLeveller.init!(
    mc::TestParallelRunMC,
    ctx::LoadLeveller.MCContext,
    params::AbstractDict,
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    mc.state = MPI.Comm_rank(comm)
    mc.try_measure_on_nonroot = get(params, :try_measure_on_nonroot, false)

    return nothing
end

function LoadLeveller.sweep!(
    mc::TestParallelRunMC,
    ctx::LoadLeveller.MCContext,
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    chosen_rank = rand(ctx.rng, 0:MPI.Comm_size(comm)-1)
    chosen_rank = MPI.Bcast(chosen_rank, 0, comm)
    addition_state = MPI.Bcast(mc.state, chosen_rank, comm)

    mc.state += sin(addition_state)

    return nothing
end

function LoadLeveller.measure!(
    mc::TestParallelRunMC,
    ctx::LoadLeveller.MCContext,
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    mean = MPI.Reduce(mc.state, +, comm)
    mean2 = MPI.Reduce(mc.state^2, +, comm)

    if MPI.Comm_rank(comm) == 0
        LoadLeveller.measure!(ctx, :test_det, sin(ctx.sweeps))
        LoadLeveller.measure!(ctx, :test, mean)
        LoadLeveller.measure!(ctx, :test2, mean2)
    end

    if mc.try_measure_on_nonroot
        LoadLeveller.measure!(ctx, :test2, 0.0)
    end

    return nothing
end

function LoadLeveller.write_checkpoint(
    mc::TestParallelRunMC,
    out::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    states = MPI.Gather(mc.state, comm)

    if MPI.Comm_rank(comm) == 0
        out["states"] = states
    end

    return nothing
end

function LoadLeveller.read_checkpoint!(
    mc::TestParallelRunMC,
    in::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    if MPI.Comm_rank(comm) == 0
        states = read(in["states"])
    else
        states = nothing
    end

    mc.state = MPI.Scatter(states, typeof(mc.state), comm)
    return nothing
end

function LoadLeveller.register_evaluables(
    ::Type{TestParallelRunMC},
    eval::LoadLeveller.Evaluator,
    params::AbstractDict,
)
    evaluate!((x, y) -> y - x^2, eval, :test4, (:test, :test2))
    return nothing
end
