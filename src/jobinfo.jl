using JSON
using Dates
using Formatting

struct TaskInfo
    name::String
    dir::String
    params::Dict
end

function walker_dir(task::TaskInfo, walker_id::Integer)
    return format("{}/walker{:04d}", task.dir, walker_id)
end

function list_walker_files(task::TaskInfo, ending::AbstractString)
    return map(
        x -> task.dir * "/" * x,
        filter(x -> occursin(Regex("^walker\\d{4,}\\.$ending\$"), x), readdir(task.dir)),
    )
end

function read_dump_progress(task::TaskInfo)
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
    task::TaskInfo;
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
    register_evaluables(MC, evaluator, task.params)

    results = Dict(
        name => ResultObservable(obs) for
        (name, obs) in merge(merged_results, evaluator.evaluables)
    )
    write_results(merge(results), task.dir * "/results.json", task.dir, task.params)
    return nothing
end

struct JobInfo
    jobname::String
    jobdir::String

    config::Dict
    tasks::Vector{TaskInfo}

    checkpoint_time::Dates.CompoundPeriod
    run_time::Dates.CompoundPeriod

    JobInfo(jobfile_name::AbstractString) = begin
        jobdata = JSON.parsefile(jobfile_name)
        jobdir = dirname(jobfile_name)
        tasks = sort(
            [TaskInfo(k, jobdir * "/" * k, v) for (k, v) in jobdata["tasks"]];
            lt = (x, y) -> x.name < y.name,
        )

        function parse_duration(duration::AbstractString)::Dates.CompoundPeriod
            m = match(r"((?<hours>\d+):)?((?<minutes>\d+):).(?<seconds>\d+)", duration)

            conv(x) = x == nothing ? 0 : parse(Int32, x)
            return Dates.Hour(conv(m[:hours])) +
                   Dates.Minute(conv(m[:minutes])) +
                   Dates.Second(conv(m[:seconds]))
        end

        checkpoint_time = parse_duration(jobdata["jobconfig"]["mc_checkpoint_time"])
        run_time = parse_duration(jobdata["jobconfig"]["mc_runtime"])

        new(
            jobdata["jobname"],
            jobdir,
            jobdata["jobconfig"],
            tasks,
            checkpoint_time,
            run_time,
        )
    end
end

function concatenate_results(job::JobInfo)
    open("$(job.jobdir)/../$(job.jobname).results.json", "w") do out
        results = map(job.tasks) do task
            open(task.dir * "/results.json", "r") do in
                return JSON.parse(in)
            end
        end
        JSON.print(out, results, 1)
    end
    return nothing
end


function create_job_directory(job::JobInfo)
    for task in job.tasks
        mkpath(task.dir)
    end
    return nothing
end
