using JSON
using Dates
using Formatting

struct JobInfo
    name::String
    dir::String

    tasks::Vector{TaskInfo}

    checkpoint_time::Dates.CompoundPeriod
    run_time::Dates.CompoundPeriod

    JobInfo(job_file_name::AbstractString; checkpoint_time::Union{AbstractString, Dates.CompoundPeriod}, run_time::Union{AbstractString, Dates.CompoundPeriod}, tasks=Vector{TaskInfo}) = begin
        new(
            basename(job_file_name),
            job_file_name * ".data",
            tasks,
            parse_duration(checkpoint_time),
            parse_duration(run_time),
        )
    end
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
    return nothing
end
