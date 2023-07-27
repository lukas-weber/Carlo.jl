import Carlo
using HDF5
using MPI

struct TestMC <: AbstractMC end

TestMC(params::AbstractDict) = TestMC()

Carlo.init!(mc::TestMC, ctx::MCContext, params::AbstractDict) = nothing
Carlo.sweep!(mc::TestMC, ctx::MCContext) = nothing

function Carlo.measure!(mc::TestMC, ctx::MCContext)
    measure!(ctx, :test, ctx.sweeps)
    measure!(ctx, :test2, ctx.sweeps^2)
    measure!(ctx, :test_vec, [ctx.sweeps, sin(ctx.sweeps)])
    measure!(ctx, :test_rng, rand(ctx.rng))

    return nothing
end

Carlo.write_checkpoint(mc::TestMC, out::HDF5.Group) = nothing
Carlo.read_checkpoint!(mc::TestMC, in::HDF5.Group) = nothing

function Carlo.register_evaluables(::Type{TestMC}, eval::Evaluator, params::AbstractDict)
    evaluate!((x, y) -> y - x^2, eval, :test4, (:test, :test2))
    evaluate!(x -> x^2, eval, :test5, (:test,))
    evaluate!(eval, :test6, (:test_vec,)) do x
        r = zero(x)
        r[1] = x[1]
        return r
    end

    return nothing
end

mutable struct TestParallelRunMC <: AbstractMC
    state::Float64
    try_measure_on_nonroot::Bool
end

TestParallelRunMC(params::AbstractDict) = TestParallelRunMC(0, false)

function Carlo.init!(
    mc::TestParallelRunMC,
    ctx::MCContext,
    params::AbstractDict,
    comm::MPI.Comm,
)
    @assert comm != MPI.COMM_NULL
    mc.state = MPI.Comm_rank(comm)
    mc.try_measure_on_nonroot = get(params, :try_measure_on_nonroot, false)

    return nothing
end

function Carlo.sweep!(mc::TestParallelRunMC, ctx::MCContext, comm::MPI.Comm)
    @assert comm != MPI.COMM_NULL
    chosen_rank = rand(ctx.rng, 0:MPI.Comm_size(comm)-1)
    chosen_rank = MPI.Bcast(chosen_rank, 0, comm)
    addition_state = MPI.Bcast(mc.state, chosen_rank, comm)

    mc.state += sin(addition_state)

    return nothing
end

function Carlo.measure!(mc::TestParallelRunMC, ctx::MCContext, comm::MPI.Comm)
    @assert comm != MPI.COMM_NULL
    mean = MPI.Reduce(mc.state, +, comm)
    mean2 = MPI.Reduce(mc.state^2, +, comm)

    if MPI.Comm_rank(comm) == 0
        measure!(ctx, :test_det, sin(ctx.sweeps))
        measure!(ctx, :test, mean)
        measure!(ctx, :test2, mean2)

        measure!(ctx, :test_local, rand(ctx.rng))
    end

    if mc.try_measure_on_nonroot
        measure!(ctx, :test2, 0.0)
    end

    return nothing
end

function Carlo.write_checkpoint(
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

function Carlo.read_checkpoint!(
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

function Carlo.register_evaluables(
    ::Type{TestParallelRunMC},
    eval::Evaluator,
    params::AbstractDict,
)
    evaluate!((x, y) -> y - x^2, eval, :test4, (:test, :test2))
    return nothing
end
