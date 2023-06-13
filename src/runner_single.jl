using Dates
using Logging
using .JobTools: JobInfo

abstract type AbstractRunner end

const DefaultRNG = Random.Xoshiro

mutable struct SingleRunner{MC<:AbstractMC} <: AbstractRunner
    job::JobInfo
    run::Union{Run{MC,DefaultRNG},Nothing}

    time_start::Dates.DateTime
    time_last_checkpoint::Dates.DateTime

    task_id::Union{Int32,Nothing}
    tasks::Vector{RunnerTask}

    function SingleRunner{MC}(job::JobInfo) where {MC<:AbstractMC}
        return new{MC}(job, nothing, Dates.now(), Dates.now(), 1, RunnerTask[])
    end
end

function start(::Type{SingleRunner{MC}}, job::JobInfo) where {MC<:AbstractMC}
    JobTools.create_job_directory(job)
    runner = SingleRunner{MC}(job)
    runner.time_start = Dates.now()
    runner.time_last_checkpoint = runner.time_start

    runner.tasks = map(
        x -> RunnerTask(x.target_sweeps, x.sweeps, x.dir, 0),
        JobTools.read_progress(runner.job),
    )
    runner.task_id = get_new_task_id(runner.tasks, length(runner.tasks))

    while runner.task_id !== nothing && !JobTools.is_end_time(runner.job, runner.time_start)
        task = runner.job.tasks[runner.task_id]
        runner_task = runner.tasks[runner.task_id]
        rundir = run_dir(runner_task, 1)

        runner.run = read_checkpoint(Run{MC,DefaultRNG}, rundir, task.params)
        if runner.run !== nothing
            @info "read $rundir"
        else
            runner.run = Run{MC,DefaultRNG}(task.params)
            @info "initialized $rundir"
        end

        while !is_done(runner_task) && !JobTools.is_end_time(runner.job, runner.time_start)
            runner_task.sweeps += step!(runner.run)

            if JobTools.is_checkpoint_time(runner.job, runner.time_last_checkpoint)
                write_checkpoint(runner)
            end
        end

        write_checkpoint(runner)

        taskdir = runner_task.dir
        @info "merging $(taskdir)"
        merge_results(MC, runner_task.dir; parameters = task.params)

        runner.task_id = get_new_task_id(runner.tasks, runner.task_id)
    end

    JobTools.concatenate_results(runner.job)
    @info "Job complete."

    return nothing
end

function get_new_task_id(
    tasks::AbstractVector{RunnerTask},
    old_id::Integer,
)::Union{Integer,Nothing}
    next_unshifted = findfirst(x -> !is_done(x), circshift(tasks, -old_id))
    if next_unshifted === nothing
        return nothing
    end

    return (next_unshifted + old_id - 1) % length(tasks) + 1
end

get_new_task_id(::AbstractVector{RunnerTask}, ::Nothing) = nothing

function write_checkpoint(runner::SingleRunner)
    runner.time_last_checkpoint = Dates.now()
    rundir = run_dir(runner.tasks[runner.task_id], 1)
    write_checkpoint!(runner.run, rundir)
    write_checkpoint_finalize(rundir)
    @info "checkpointing $rundir"

    return nothing
end
