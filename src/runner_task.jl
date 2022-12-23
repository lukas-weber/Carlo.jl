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

function list_walker_files(task::RunnerTask, ending::AbstractString)
    return map(
        x -> task.dir * "/" * x,
        filter(x -> occursin(Regex("^walker\\d{4,}\\.$ending\$"), x), readdir(task.dir)),
    )
end

function read_dump_progress(task::RunnerTask)
    return mapreduce(+, list_walker_files(task, "dump\\.h5"), init = Int64(0)) do dumpname
        sweeps = 0
        h5open(dumpname, "r") do f
            sweeps =
                max(0, read(f["context/sweeps"]) - read(f["context/thermalization_sweeps"]))
        end
        return sweeps
    end
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
        list_walker_files(task, "meas\\.h5");
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
