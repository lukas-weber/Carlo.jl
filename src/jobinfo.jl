using JSON
using Unmarshal
using Dates
using Formatting

struct JobInfo
    name::String
    dir::String

    tasks::Vector{TaskInfo}

    checkpoint_time::Dates.Second
    run_time::Dates.Second
end

function JobInfo(
    job_file_name::AbstractString;
    checkpoint_time::Union{AbstractString,Dates.Second},
    run_time::Union{AbstractString,Dates.Second},
    tasks = Vector{TaskInfo},
)
    return JobInfo(
        basename(job_file_name),
        job_file_name * ".data",
        tasks,
        parse_duration(checkpoint_time),
        parse_duration(run_time),
    )
end

function read_jobinfo_file(jobdir::AbstractString)
    return Unmarshal.unmarshal(JobInfo, JSON.parsefile(jobdir * "/parameters.json"))
end

function task_dir(job::JobInfo, task::TaskInfo)
    return format("{}/{}", job.dir, task.name)
end

function concatenate_results(job::JobInfo)
    open("$(job.dir)/../$(job.name).results.json", "w") do out
        results = map(job.tasks) do task
            open(task_dir(job, task) * "/results.json", "r") do in
                return JSON.parse(in)
            end
        end
        JSON.print(out, results, 1)
    end
    return nothing
end

function create_job_directory(job::JobInfo)
    mkpath(job.dir)
    for task in job.tasks
        mkpath(task_dir(job, task))
    end

    open(job.dir * "/parameters.json", "w") do file
        JSON.print(file, job)
    end
    return nothing
end

function read_progress(job::JobInfo)::Vector{RunnerTask}
    return map(job.tasks) do task
        target_sweeps = task.params[:sweeps]
        sweeps = read_dump_progress(task_dir(job, task))
        return RunnerTask(target_sweeps, sweeps, task_dir(job, task), 0)
    end |> collect
end

is_checkpoint_time(job::JobInfo, time_last_checkpoint::Dates.DateTime) =
    Dates.now() >= time_last_checkpoint + job.checkpoint_time
is_end_time(job::JobInfo, time_start::Dates.DateTime) =
    Dates.now() >= time_start + job.run_time
