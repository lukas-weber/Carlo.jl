import JSON
import Dates
import Formatting

struct TaskInfo
    name::String
    params::Dict
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
        tasks = [TaskInfo(k, v) for (k, v) in jobdata["tasks"]]
        
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

function rundir(job::JobInfo, task_id::Integer, run_id::Integer)
    return format("{}/{:04d}", taskdir(job, task_id), run_id)
end

function taskdir(job::JobInfo, task_id::Integer)
    return job.jobdir * "/" * job.tasks[task_id].name
end

function read_dump_progress(job::JobInfo, task_id::Integer)
    return mapreduce(+, list_run_files(taskdir(job, task_id), "dump\\.h5"), init=Int64(0)) do dumpname
        h5open(dumpname, "r") do f
            sweeps = f["sweeps"]
        end
        return sweeps
    end
end

function list_run_files(taskdir::AbstractString, ending::AbstractString)
    return filter(
        x -> occursin(Regex("^run\\d{4,}\\.{}" * ending * "\$"), x),
        readdir(taskdir),
    )
end

function create_job_directory(job::JobInfo)
    for (task_id, task) in enumerate(job.tasks)
        mkpath(taskdir(job, task_id))
    end
    return nothing
end
