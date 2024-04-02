mutable struct SchedulerTask
    target_sweeps::Int64
    sweeps::Int64

    dir::String
    scheduled_runs::Int64
    max_scheduled_runs::Int64
end

SchedulerTask(target_sweeps::Integer, sweeps::Integer, dir::AbstractString) =
    SchedulerTask(target_sweeps, sweeps, dir, 0, typemax(Int64))

is_done(task::SchedulerTask) = task.sweeps >= task.target_sweeps

function run_dir(task::SchedulerTask, run_id::Integer)
    return @sprintf "%s/run%04d" task.dir run_id
end

function merge_results(
    ::Type{MC},
    taskdir::AbstractString;
    parameters::Dict{Symbol,Any},
    data_type::Type{T} = Float64,
    rebin_length::Union{Integer,Nothing} = get(parameters, :rebin_length, nothing),
    sample_skip::Integer = get(parameters, :rebin_sample_skip, 0),
) where {MC<:AbstractMC,T}
    merged_results = merge_results(
        JobTools.list_run_files(taskdir, "meas\\.h5"),
        data_type;
        rebin_length = rebin_length,
        sample_skip = sample_skip,
    )

    evaluator = Evaluator(merged_results)
    register_evaluables(MC, evaluator, parameters)

    results = Dict(
        name => ResultObservable(obs) for
        (name, obs) in merge(merged_results, evaluator.evaluables)
    )
    write_results(
        merge(results),
        taskdir * "/results.json",
        taskdir,
        parameters,
        Version(MC),
    )
    return nothing
end
