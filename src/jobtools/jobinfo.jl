using JSON
using Dates
using Random

"""Parse a duration of the format `[[[days-]hours:]minutes]:seconds`."""
function parse_duration(duration::AbstractString)::Dates.Period
    m = match(
        r"^((((?<days>\d+)-)?(?<hours>\d+):)?(?<minutes>\d+):)?(?<seconds>\d+)$",
        duration,
    )
    if isnothing(m)
        error("$duration does not match [[HH:]MM:]SS")
    end

    conv(x) = parse(UInt, something(x, "0"))
    return convert(
        Dates.Second,
        Day(conv(m[:days])) +
        Hour(conv(m[:hours])) +
        Minute(conv(m[:minutes])) +
        Second(conv(m[:seconds])),
    )
end

parse_duration(duration::Dates.Period) = duration

"""
    JobInfo(
        job_directory_prefix::AbstractString,
        mc::Type;
        checkpoint_time::Union{AbstractString, Dates.Period},
        run_time::Union{AbstractString, Dates.Period},
        tasks::Vector{TaskInfo},
        rng::Type = Random.Xoshiro,
        ranks_per_run::Union{Integer, Symbol} = 1,
    )

Holds all information required for a Monte Carlo calculation. The data of the calculation (parameters, results, and checkpoints) will be saved under `job_directory_prefix`.

`mc` is the the type of the algorithm to use, implementing the [abstract_mc](@ref) interface.

`checkpoint_time` and `run_time` specify the interval between checkpoints and the total desired run_time of the simulation. Both may be specified as a string of format `[[hours:]minutes:]seconds`

Each job contains a set of `tasks`, corresponding
to different sets of simulation parameters that should be run in parallel. The [`TaskMaker`](@ref) type can be used to conveniently generate them.

`rng` sets the type of random number generator that should be used.

Setting the optional parameter `ranks_per_run > 1` enables [Parallel run mode](@ref parallel_run_mode). The special value `ranks_per_run = :all` uses all available ranks for a single run."""
struct JobInfo
    name::String
    dir::String

    mc::Type
    rng::Type

    tasks::Vector{TaskInfo}

    checkpoint_time::Dates.Second
    run_time::Dates.Second

    ranks_per_run::Union{Int,Symbol}
end

function JobInfo(
    job_file_name::AbstractString,
    mc::Type;
    rng::Type = Random.Xoshiro,
    checkpoint_time::Union{AbstractString,Dates.Period},
    run_time::Union{AbstractString,Dates.Period},
    tasks::Vector{TaskInfo},
    ranks_per_run::Union{Integer,Symbol} = 1,
)

    job_file_name = expanduser(job_file_name)

    if (ranks_per_run isa Symbol && ranks_per_run != :all) ||
       (ranks_per_run isa Integer && ranks_per_run < 1)
        throw(
            ArgumentError(
                "ranks_per_run should be positive integer or :all, not $ranks_per_run.",
            ),
        )
    end

    return JobInfo(
        basename(job_file_name),
        job_file_name * ".data",
        mc,
        rng,
        tasks,
        round(parse_duration(checkpoint_time), Second),
        round(parse_duration(run_time), Second),
        ranks_per_run,
    )
end

function task_dir(job::JobInfo, task::TaskInfo)
    return "$(job.dir)/$(task.name)"
end

"""
    run_time_from_slurm(;grace_factor=0.95, default=Hour(24))

When running inside a Slurm job, returns the remaining wall-clock time based on the environment variable `SLURM_JOB_END_TIME`. The result is multiplied by `grace_factor` to allow for a small period for wrapping up the calculation and saving the final results.

The result of this function can be used for the `run_time` parameter of the [`JobInfo`](@ref) struct.

If `SLURM_JOB_END_TIME` is not set, `default` is returned.
"""
function run_time_from_slurm(; grace_factor = 0.95, default = Hour(24))
    if !haskey(ENV, "SLURM_JOB_END_TIME")
        return default
    end

    remaining_time = unix2datetime(parse(Int, ENV["SLURM_JOB_END_TIME"])) - now()
    return Millisecond(round(Int64, grace_factor * (remaining_time / Millisecond(1))))
end

"""
    result_filename(job::JobInfo)

Returns the filename of the `.results.json` file containing the merged results of the calculation of `job`.
"""
result_filename(job::JobInfo) = "$(job.dir)/../$(job.name).results.json"

function concatenate_results(job::JobInfo)
    open(result_filename(job), "w") do out
        results = skipmissing(map(job.tasks) do task
            try
                open(task_dir(job, task) * "/results.json", "r") do in
                    return JSON.parse(in; allownan = true)
                end
            catch e
                if !isa(e, Base.SystemError)
                    rethrow()
                end
                return missing
            end
        end)
        JSON.json(out, collect(results); pretty = 1, allownan = true)
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
        num_runs = length(sweeps)

        thermalized_sweeps = sum(
            max(0, total_sweeps - therm_sweeps) for (total_sweeps, therm_sweeps) in sweeps;
            init = 0,
        )

        thermalization_fraction = 0
        if num_runs > 0
            thermalization_fraction =
                mean(ts == 0 ? 1.0 : min(s, ts) / ts for (s, ts) in sweeps)
        end

        return TaskProgress(
            target_sweeps,
            thermalized_sweeps,
            num_runs,
            thermalization_fraction,
            task_dir(job, task),
        )
    end |> collect
end

is_checkpoint_time(job::JobInfo, time_last_checkpoint::Dates.DateTime) =
    Dates.now() >= time_last_checkpoint + job.checkpoint_time
is_end_time(job::JobInfo, time_start::Dates.DateTime) =
    Dates.now() >= time_start + job.run_time
