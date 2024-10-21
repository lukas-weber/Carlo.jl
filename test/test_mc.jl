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

function Carlo.register_evaluables(
    ::Type{TestMC},
    eval::AbstractEvaluator,
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
    mc.state = MPI.Comm_rank(comm)
    mc.try_measure_on_nonroot = get(params, :try_measure_on_nonroot, false)

    return nothing
end

function Carlo.sweep!(mc::TestParallelRunMC, ctx::MCContext, comm::MPI.Comm)
    chosen_rank = rand(ctx.rng, 0:MPI.Comm_size(comm)-1)
    chosen_rank = MPI.Bcast(chosen_rank, 0, comm)
    addition_state = MPI.Bcast(mc.state, chosen_rank, comm)

    mc.state += sin(addition_state)

    return nothing
end

function Carlo.measure!(mc::TestParallelRunMC, ctx::MCContext, comm::MPI.Comm)
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
    eval::AbstractEvaluator,
    params::AbstractDict,
)
    evaluate!((x, y) -> y - x^2, eval, :test4, (:test, :test2))
    return nothing
end

mutable struct TestTemperedMC <: AbstractMC
    μ::Float64
    x::Float64
end

TestTemperedMC(params::AbstractDict) = TestTemperedMC(params[:μ], 0)

Carlo.init!(mc::TestTemperedMC, ctx::MCContext, params::AbstractDict) = nothing
function Carlo.sweep!(mc::TestTemperedMC, ctx::MCContext)
    xnew = mc.x + 0.07 * randn(ctx.rng)
    if rand(ctx.rng) < test_distribution(xnew, mc.μ) / test_distribution(mc.x, mc.μ)
        mc.x = xnew
    end
end

test_distribution(x, μ; f = 2) =
    (exp(-(x - μ)^2 * f * (1 + μ^4)) + exp(-(x + μ)^2 * (1 + μ^4))) * 2 * (1 + μ^4) /
    (sqrt(2π) * (1 + 1 / f))
test_distribution_x(μ; f = 2) = (f^-0.5 - 1) / (f^-0.5 + 1) * μ
test_distribution_x²(μ; f = 2) = (f^-1.5 + 1) / (f^-0.5 + 1) / (2 * (1 + μ^4)) + μ^2

function Carlo.measure!(mc::TestTemperedMC, ctx::MCContext)
    measure!(ctx, :X², mc.x^2)
    measure!(ctx, :X, mc.x)
    measure!(ctx, :XX², [mc.x, mc.x^2])

    return nothing
end

function Carlo.write_checkpoint(mc::TestTemperedMC, out::HDF5.Group)
    out["x"] = mc.x
end

function Carlo.read_checkpoint!(mc::TestTemperedMC, in::HDF5.Group)
    mc.x = read(in, "x")
end

function Carlo.register_evaluables(
    ::Type{TestTemperedMC},
    eval::AbstractEvaluator,
    params::AbstractDict,
)
    evaluate!((x, x², xx²) -> xx² .- [x, x²], eval, :Zero, (:X, :X², :XX²))
    return nothing
end

function Carlo.parallel_tempering_log_weight_ratio(
    mc::TestTemperedMC,
    parameter_name::Symbol,
    new_value,
)
    @assert parameter_name == :μ
    return log(test_distribution(mc.x, new_value) / test_distribution(mc.x, mc.μ))
end

function Carlo.parallel_tempering_change_parameter!(
    mc::TestTemperedMC,
    parameter_name::Symbol,
    new_value,
)
    @assert parameter_name == :μ
    mc.μ = new_value
    return nothing
end
