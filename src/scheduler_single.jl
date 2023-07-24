using Dates
using Logging
using .JobTools: JobInfo

abstract type AbstractScheduler end

const DefaultRNG = Random.Xoshiro

mutable struct SingleScheduler{MC<:AbstractMC} <: AbstractScheduler
    job::JobInfo
    run::Union{Run{MC,DefaultRNG},Nothing}

    time_start::Dates.DateTime
    time_last_checkpoint::Dates.DateTime

    task_id::Union{Int,Nothing}
    tasks::Vector{SchedulerTask}

    function SingleScheduler{MC}(job::JobInfo) where {MC<:AbstractMC}
        return new{MC}(job, nothing, Dates.now(), Dates.now(), 1, SchedulerTask[])
    end
end

function start(::Type{SingleScheduler}, job::JobInfo)
    JobTools.create_job_directory(job)
    scheduler = SingleScheduler{job.mc}(job)
    scheduler.time_start = Dates.now()
    scheduler.time_last_checkpoint = scheduler.time_start

    scheduler.tasks = map(
        x -> SchedulerTask(x.target_sweeps, x.sweeps, x.dir, 0),
        JobTools.read_progress(scheduler.job),
    )
    scheduler.task_id = get_new_task_id(scheduler.tasks, length(scheduler.tasks))

    while scheduler.task_id !== nothing &&
        !JobTools.is_end_time(scheduler.job, scheduler.time_start)
        task = scheduler.job.tasks[scheduler.task_id]
        scheduler_task = scheduler.tasks[scheduler.task_id]
        rundir = run_dir(scheduler_task, 1)

        scheduler.run = read_checkpoint(Run{job.mc,DefaultRNG}, rundir, task.params)
        if scheduler.run !== nothing
            @info "read $rundir"
        else
            scheduler.run = Run{job.mc,DefaultRNG}(task.params)
            @info "initialized $rundir"
        end

        while !is_done(scheduler_task) &&
            !JobTools.is_end_time(scheduler.job, scheduler.time_start)
            scheduler_task.sweeps += step!(scheduler.run)

            if JobTools.is_checkpoint_time(scheduler.job, scheduler.time_last_checkpoint)
                write_checkpoint(scheduler)
            end
        end

        write_checkpoint(scheduler)

        taskdir = scheduler_task.dir
        @info "merging $(taskdir)"
        merge_results(job.mc, scheduler_task.dir; parameters = task.params)

        scheduler.task_id = get_new_task_id(scheduler.tasks, scheduler.task_id)
    end

    JobTools.concatenate_results(scheduler.job)

    all_done = scheduler.task_id === nothing
    @info "stopping due to $(all_done ? "completion" : "time limit")"

    return !all_done
end

function get_new_task_id(
    tasks::AbstractVector{SchedulerTask},
    old_id::Integer,
)::Union{Integer,Nothing}
    next_unshifted = findfirst(x -> !is_done(x), circshift(tasks, -old_id))
    if next_unshifted === nothing
        return nothing
    end

    return (next_unshifted + old_id - 1) % length(tasks) + 1
end

get_new_task_id(::AbstractVector{SchedulerTask}, ::Nothing) = nothing

function write_checkpoint(scheduler::SingleScheduler)
    scheduler.time_last_checkpoint = Dates.now()
    rundir = run_dir(scheduler.tasks[scheduler.task_id], 1)
    write_checkpoint!(scheduler.run, rundir)
    write_checkpoint_finalize(rundir)
    @info "checkpointing $rundir"

    return nothing
end
