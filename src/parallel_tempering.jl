# MPI tags
const PT_WEIGHT_MSG = 4573792
const PT_SWITCH_MSG = 4573793

struct ParallelMeasurements
    queue::Vector{Tuple{Symbol,Any}}
end

ParallelMeasurements() = ParallelMeasurements(Vector{Tuple{Symbol,Any}}())

Carlo.add_sample!(measure::ParallelMeasurements, name::Symbol, value) =
    push!(measure.queue, (name, value))

function make_parallel_context(ctx::MCContext, parallel_measure::ParallelMeasurements)
    return MCContext(ctx.sweeps, ctx.thermalization_sweeps, ctx.rng, parallel_measure)
end

function collect_parallel_measurements!(
    parallel_measure::ParallelMeasurements,
    comm::MPI.Comm,
)
    all_measurements = MPI.gather(parallel_measure.queue, comm)
    empty!(parallel_measure.queue)

    if MPI.Comm_rank(comm) == 0
        if !allequal(first.(meas) for meas in all_measurements)
            error("parallel measurements are out of order between different ranks")
        end

        merged_measurements = Tuple{Symbol,AbstractArray}[]
        for (s, (obsname, _)) in enumerate(all_measurements[1])
            push!(
                merged_measurements,
                (obsname, stack(meas[s][2] for meas in all_measurements)),
            )
        end

        return merged_measurements
    end
    return nothing
end

function synchronize_measurements!(
    ctx::MCContext,
    parallel_measure::ParallelMeasurements,
    chain_idx,
    comm::MPI.Comm,
)
    measurements = collect_parallel_measurements!(parallel_measure, comm)
    chain_permutation = MPI.gather(chain_idx, comm)

    if MPI.Comm_rank(comm) == 0
        chain_inv_permutation = invperm(chain_permutation)

        for (obsname, sample) in measurements
            measure!(
                ctx,
                obsname,
                @view(sample[ntuple(_ -> :, ndims(sample) - 1)..., chain_inv_permutation]),
            )
        end
    end

    return nothing
end

function write_checkpoint(parallel_measure::ParallelMeasurements, out::HDF5.Group)
    values = Dict{Symbol,Any}()
    for (i, (name, val)) in enumerate(parallel_measure.queue)
        push!(get!(() -> [], values, name), (i, val))
    end

    out["queue_length"] = length(parallel_measure.queue)

    for (name, vals) in values
        g = create_group(out, "names/$(name)")

        g["order"] = first.(vals)
        g["values"] = stack(last, vals)
    end
end

function read_checkpoint(::Type{ParallelMeasurements}, in::HDF5.Group)
    saved_values = read(in, "names")

    queue = Vector{Tuple{Symbol,Any}}(
        undef,
        maximum(x -> maximum(x["order"]), values(saved_values)),
    )

    collapse_scalar(x) = x
    collapse_scalar(x::AbstractArray{<:Any,0}) = x[]

    for (name, vals) in saved_values
        for (i, v) in
            zip(vals["order"], eachslice(vals["values"]; dims = ndims(vals["values"])))
            queue[i] = (Symbol(name), collapse_scalar(v))
        end
    end

    return ParallelMeasurements(queue)
end


"""
    ParallelTemperingMC <: AbstractMC

An implementation of the [parallel run mode](@ref parallel_run_mode) `AbstractMC` interface that runs other `AbstractMC` implementations with parallel tempering.

The child implementation is expected to implement

- [`parallel_tempering_log_weight_ratio`](@ref)
- [`parallel_tempering_change_parameter!`](@ref)
"""
mutable struct ParallelTemperingMC{T} <: AbstractMC
    parameter_name::Symbol
    parameter_values::Vector{T}

    tempering_interval::Int

    parallel_measure::ParallelMeasurements

    chain_idx::Int
    child_mc::AbstractMC
end

"""
    Carlo.parallel_tempering_change_parameter!(mc::YourMC, parameter_name::Symbol, new_value)

During a parallel tempering simulation, changes the parameter named `parameter_name` to `new_value` and performs all necessary updates to the internal structure of `YourMC`.
"""
function parallel_tempering_change_parameter! end

@doc raw"""
    Carlo.parallel_tempering_log_weight_ratio(mc::YourMC, parameter_name::Symbol, new_value)

Let ``W(x, p)`` be the the weight of the Monte Carlo configuration ``x`` at the current value of the parameter ``p`` (specified by `parameter_name`), and ``W(x,p')`` be the weight after the parameter has been changed to `new_value`.

This function then returns ``\log W(x,p')/W(x,p)``.
"""
function parallel_tempering_log_weight_ratio end

function ParallelTemperingMC(params::AbstractDict)
    config = params[:parallel_tempering]
    MC = config.mc
    tempering_interval = config.interval

    comm = params[:_comm]
    chain_idx = MPI.Comm_rank(comm) + 1

    modified_params = deepcopy(params)
    modified_params[config.parameter] = config.values[chain_idx]

    return ParallelTemperingMC(
        config.parameter,
        collect(config.values),
        config.interval,
        ParallelMeasurements(),
        chain_idx,
        MC(modified_params),
    )
end

function Carlo.init!(
    mc::ParallelTemperingMC,
    ctx::MCContext,
    params::AbstractDict,
    comm::MPI.Comm,
)
    modified_params = deepcopy(params)
    modified_params[mc.parameter_name] = mc.parameter_values[mc.chain_idx]

    Carlo.init!(mc.child_mc, ctx, modified_params)
end

function Carlo.sweep!(mc::ParallelTemperingMC, ctx::MCContext, comm::MPI.Comm)
    Carlo.sweep!(mc.child_mc, make_parallel_context(ctx, mc.parallel_measure))

    if ctx.sweeps % mc.tempering_interval == 0
        synchronize_measurements!(ctx, mc.parallel_measure, mc.chain_idx, comm)
        tempering_update!(mc, ctx, comm)
    end
    return nothing
end

function tempering_update!(mc::ParallelTemperingMC, ctx::MCContext, comm::MPI.Comm)
    chain_permutation = MPI.Allgather(mc.chain_idx, comm)

    pairing_offset = (ctx.sweeps ÷ mc.tempering_interval) & 1

    if mc.chain_idx & 1 == pairing_offset
        partner_chain_idx = mc.chain_idx + 1
        if partner_chain_idx > length(mc.parameter_values)
            return
        end
    else
        partner_chain_idx = mc.chain_idx - 1
        if partner_chain_idx < 1
            return
        end
    end

    partner_rank = findfirst(==(partner_chain_idx), chain_permutation) - 1
    w = parallel_tempering_log_weight_ratio(
        mc.child_mc,
        mc.parameter_name,
        mc.parameter_values[partner_chain_idx],
    )

    if mc.chain_idx & 1 == pairing_offset
        partner_w = MPI.Recv(Float64, comm; source = partner_rank, tag = PT_WEIGHT_MSG)

        accept_switch = rand(ctx.rng) < exp(w + partner_w)
        MPI.Send(accept_switch, comm; dest = partner_rank, tag = PT_SWITCH_MSG)
    else
        MPI.Send(Float64(w), comm; dest = partner_rank, tag = PT_WEIGHT_MSG)
        accept_switch = MPI.Recv(Bool, comm; source = partner_rank, tag = PT_SWITCH_MSG)
    end

    if accept_switch
        mc.chain_idx = partner_chain_idx
        parallel_tempering_change_parameter!(
            mc.child_mc,
            mc.parameter_name,
            mc.parameter_values[mc.chain_idx],
        )
    end
end

function Carlo.measure!(mc::ParallelTemperingMC, ctx::MCContext, comm::MPI.Comm)
    parallel_ctx = make_parallel_context(ctx, mc.parallel_measure)
    Carlo.measure!(mc.child_mc, parallel_ctx)

    if ctx.sweeps % mc.tempering_interval == 0
        Carlo.measure!(parallel_ctx, :ParallelTemperingPermutation, MPI.Comm_rank(comm) + 1)
    end
end

struct MultiplexEvaluator <: AbstractEvaluator
    entry_count::Int
    evals::Dict{Symbol,Tuple{Tuple,Vector{Function}}}
end
MultiplexEvaluator(entry_count) =
    MultiplexEvaluator(entry_count, Dict{Symbol,Tuple{Tuple,Vector{Function}}}())

function evaluate!(
    evaluation::Func,
    eval::MultiplexEvaluator,
    name::Symbol,
    ingredients::NTuple{N,Symbol},
) where {Func,N}
    if !haskey(eval.evals, name)
        eval.evals[name] = (ingredients, Function[])
    end

    if ingredients != eval.evals[name][1]
        error(
            "evaluable $name has inconsistent ingredients ($ingredients != $(eval.evals[name][1])",
        )
    end

    push!(eval.evals[name][2], evaluation)
end

function run_evaluations!(multi_eval::MultiplexEvaluator, eval::Evaluator)
    for (name, (ingredients, funcs)) in multi_eval.evals
        if length(funcs) != multi_eval.entry_count
            error(
                "number of multiplexed evaluables inconsistent: $name: $(length(funcs)) != $(multi_eval.entry_count). Did you call evaluate! more than once for the same evaluable?",
            )
        end

        scalarize(v) = ndims(v) == 0 ? v[] : v

        evaluate!(eval, name, ingredients) do args...
            return stack(
                func(scalarize.(sliced_args)...) for (func, sliced_args...) in
                zip(funcs, map(arg -> eachslice(arg, dims = ndims(arg)), args)...)
            )
        end
    end
end

function Carlo.register_evaluables(
    ::Type{ParallelTemperingMC},
    eval::Evaluator,
    params::AbstractDict,
)
    config = params[:parallel_tempering]
    MC = config.mc
    multi_eval = MultiplexEvaluator(length(config.values))

    for value in config.values
        modified_params = deepcopy(params)
        modified_params[config.parameter] = value

        Carlo.register_evaluables(config.mc, multi_eval, modified_params)
    end
    run_evaluations!(multi_eval, eval)

    return nothing
end

function Carlo.write_checkpoint(
    mc::ParallelTemperingMC,
    out::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    chain_permutation = MPI.Gather(mc.chain_idx, comm)
    child_mcs = MPI.gather(mc.child_mc, comm)
    parallel_measures = MPI.gather(mc.parallel_measure, comm)

    if MPI.Comm_rank(comm) == 0
        out["chain_permutation"] = chain_permutation

        for (i, (child_mc, parallel_measure)) in
            enumerate(zip(child_mcs, parallel_measures))
            Carlo.write_checkpoint(child_mc, create_group(out, "child_mcs/$i"))
            Carlo.write_checkpoint(
                parallel_measure,
                create_group(out, "parallel_measures/$i"),
            )
        end
    end

    return nothing
end

function Carlo.read_checkpoint!(
    mc::ParallelTemperingMC,
    in::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    child_mcs = MPI.gather(mc.child_mc, comm)

    if MPI.Comm_rank(comm) == 0
        chain_permutation = read(in, "chain_permutation")
        parallel_measures = [
            Carlo.read_checkpoint(ParallelMeasurements, in["parallel_measures/$i"]) for
            i in eachindex(child_mcs)
        ]

        for (i, child_mc) in enumerate(child_mcs)
            Carlo.read_checkpoint!(child_mc, in["child_mcs/$i"])
        end
    else
        chain_permutation = nothing
    end

    mc.chain_idx = MPI.scatter(chain_permutation, comm)
    mc.child_mc = MPI.scatter(child_mcs, comm)

    mc.parallel_measure = MPI.scatter(parallel_measures, comm)

    parallel_tempering_change_parameter!(
        mc.child_mc,
        mc.parameter_name,
        mc.parameter_values[mc.chain_idx],
    )

    return nothing
end
