import Dates
using Logging

abstract type AbstractRunner end

mutable struct SingleRunner{MC<:AbstractMC} <: AbstractRunner
    job::JobInfo
    mc::Union{MC,Nothing}
    mcdata::Union{MCData,Nothing}

    time_start::Dates.DateTime
    time_last_checkpoint::Dates.DateTime

    task_id::Integer
    tasks::Vector{RunnerTask}

    function SingleRunner(job::JobInfo, ::Type{MC}) where {MC<:AbstractMC}
        return new{MC}(
            job,
            nothing,
            nothing,
            Dates.now(),
            Dates.now(),
            -1,
            Vector{RunnerTask}(),
        )
    end
end

function start!(runner::SingleRunner{MC}) where {MC<:AbstractMC}
    runner.time_start = Dates.now()
    runner.time_last_checkpoint = runner.time_start

    read_progress!(runner)
    runner.task_id = get_new_task_id(runner.tasks, runner.task_id)

    while runner.task_id != -1 && !time_is_up(runner)
        params = runner.job.tasks[runner.task_id].params
        rundir = run_dir(runner.job, runner.task_id)
        
        mcpair = init_from_checkpoint(rundir, params)
        if mcpair
            runner.mcdata, runner.mc = mcpair
            @info "read $rundir"
        else 
            runner.mcdata = MCData(params)
            runner.mc = MC(params)
            init!(runner.mc, params)
            @info "initialized $rundir"
        end
            
        while !is_done(runner.tasks[runner.task_id]) && !time_is_up(runner)
            sweep!(runner.sys)
            if is_thermalized(sys)
                measure!(runner.sys)
                runner.tasks[runner.task_id].sweeps += 1
            end

            if is_checkpoint_time(runner)
                write_checkpoint(runner)
            end
        end

        write_checkpoint(runner)

        taskdir = task_dir(runner.job, runner.task_id)
        write_output(runner.sys, taskdir)
        @info "merging $(taskdir)"
        merge_task(runner.job, runner.task_id)

        runner.task_id = get_new_task_id(runner.tasks, runner.task_id)
    end

    return nothing
end

function get_new_task_id(tasks::AbstractVector{RunnerTask}, old_id::Integer)
    return findfirst(x->!is_done(x), circshift(tasks, -old_id))
end

function read!(runner::SingleRunner)
    runner.tasks = map(enumerate(runner.job.tasks)) do (task_id, task)
        target_sweeps = task.params["sweeps"]
        sweeps = read_dump_progress(runner.job, task_id)
        return RunnerTask(target_sweeps, sweeps, 0)
    end |> collect

    return nothing
end

function write_checkpoint(runner::SingleRunner)
    runner.time_last_checkpoint = Dates.now()
    rundir = run_dir(runner.job, runner.task_id, 1)
    write_checkpoint(runner.sys, rundir)
    write_finalize(runner.sys, rundir)
    @info "checkpointing $(rundir)"

    return nothing
end

time_is_up(runner::SingleRunner) = Dates.now() - runner.time_start > runner.job.run_time
is_checkpoint_time(runner::SingleRunner) =
    Dates.now() - runner.time_last_checkpoint > runner.job.checkpoint_time
