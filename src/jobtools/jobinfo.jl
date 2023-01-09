using JSON
using Dates
using Formatting

"""Parse a duration of the format `[[hours:]minutes]:seconds`."""
function parse_duration(duration::AbstractString)::Dates.Period
    m = match(r"^(((?<hours>\d+):)?(?<minutes>\d+):)?(?<seconds>\d+)$", duration)
    if isnothing(m)
        error("$duration does not match [[HH:]MM:]SS")
    end

    conv(period, x) =
        isnothing(x) ? Dates.Second(0) : convert(Dates.Second, period(parse(Int32, x)))
    return conv(Dates.Hour, m[:hours]) +
           conv(Dates.Minute, m[:minutes]) +
           conv(Dates.Second, m[:seconds])
end

parse_duration(duration::Dates.Period) = duration

"""
    JobInfo(
        job_directory_prefix::AbstractString,
        mc::Type;
        checkpoint_time::Union{AbstractString, Dates.Second},
        run_time::Union{AbstractString, Dates.Second}
        tasks::Vector{TaskInfo}
    )

Holds all information required for a Monte Carlo calculation. The data of the calculation (parameters, results, and checkpoints) will be saved under `job_directory_prefix`.

`mc` is the the type of the algorithm to use, implementing the [`AbstractMC`](@ref) interface.

`checkpoint_time` and `run_time` specify the interval between checkpoints and the total desired run_time of the simulation. Both may be specified as a string of format `[[hours:]minutes:]seconds`

Each job contains a set of `tasks`, corresponding
to different sets of simulation parameters that should be run in parallel. The [`TaskMaker`](@ref) type can be used to conveniently generate them."""
struct JobInfo
    name::String
    dir::String

    mc::Type

    tasks::Vector{TaskInfo}

    checkpoint_time::Dates.Second
    run_time::Dates.Second
end

function JobInfo(
    job_file_name::AbstractString,
    mc::Type;
    checkpoint_time::Union{AbstractString,Dates.Second},
    run_time::Union{AbstractString,Dates.Second},
    tasks::Vector{TaskInfo},
)
    return JobInfo(
        basename(job_file_name),
        job_file_name * ".data",
        mc,
        tasks,
        parse_duration(checkpoint_time),
        parse_duration(run_time),
    )
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

function read_progress(job::JobInfo)
    return map(job.tasks) do task
        target_sweeps = task.params[:sweeps]
        sweeps = read_dump_progress(task_dir(job, task))
        return (
            target_sweeps = target_sweeps,
            sweeps = sweeps,
            dir = task_dir(job, task),
        )
    end |> collect
end

is_checkpoint_time(job::JobInfo, time_last_checkpoint::Dates.DateTime) =
    Dates.now() >= time_last_checkpoint + job.checkpoint_time
is_end_time(job::JobInfo, time_start::Dates.DateTime) =
    Dates.now() >= time_start + job.run_time
