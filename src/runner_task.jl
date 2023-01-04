using Formatting

mutable struct RunnerTask
    target_sweeps::Int64
    sweeps::Int64

    dir::String
    scheduled_runs::Int64
end

is_done(task::RunnerTask) = task.sweeps >= task.target_sweeps

function walker_dir(task::RunnerTask, walker_id::Integer)
    return format("{}/walker{:04d}", task.dir, walker_id)
end

function merge_results(
    ::Type{MC},
    task::RunnerTask;
    parameters::Dict{Symbol,Any},
    data_type::Type = Float64,
    rebin_length::Union{Integer,Nothing} = nothing,
    sample_skip::Integer = 0,
) where {MC<:AbstractMC}
    merged_results = merge_results(
        JobTools.list_walker_files(task.dir, "meas\\.h5");
        data_type = data_type,
        rebin_length = rebin_length,
        sample_skip = sample_skip,
    )

    evaluator = Evaluator(merged_results)
    register_evaluables(MC, evaluator, parameters)

    results = Dict(
        name => ResultObservable(obs) for
        (name, obs) in merge(merged_results, evaluator.evaluables)
    )
    write_results(merge(results), task.dir * "/results.json", task.dir, parameters)
    return nothing
end
