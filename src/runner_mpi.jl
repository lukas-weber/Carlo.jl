using Dates
using MPI
using HDF5
using .JobTools: JobInfo

@enum MPIRunnerAction begin
    A_EXIT
    A_CONTINUE
    A_NEW_TASK
    A_PROCESS_DATA_NEW_TASK
end

send_action(action::MPIRunnerAction, dest::Integer) =
    MPI.Send(action, MPI.COMM_WORLD; dest = dest, tag = T_ACTION)
recv_action() = MPI.Recv(MPIRunnerAction, MPI.COMM_WORLD; source = 0, tag = T_ACTION)


struct MPIRunnerNewJobResponse
    task_id::Int32
    run_id::Int32
    sweeps_until_comm::UInt64
end

struct MPIRunnerBusyResponse
    task_id::Int32
    sweeps_since_last_query::UInt64
end

const T_STATUS = 1
const T_BUSY_STATUS = 2
const T_ACTION = 3
const T_NEW_TASK = 4

@enum MPIRunnerStatus begin
    S_IDLE
    S_BUSY
    S_TIMEUP
end

struct MPIRunner{MC<:AbstractMC} <: AbstractRunner end

mutable struct MPIRunnerController <: AbstractRunner
    num_active_ranks::Int32

    task_id::Union{Int32,Nothing}
    tasks::Vector{RunnerTask}

    function MPIRunnerController(job::JobInfo, active_ranks::Integer)
        return new(
            active_ranks,
            1,
            map(
                x -> RunnerTask(x.target_sweeps, x.sweeps, x.dir, 0),
                JobTools.read_progress(job),
            ),
        )
    end
end

mutable struct MPIRunnerWorker{MC<:AbstractMC}
    task_id::Int32
    run_id::Int32

    task::RunnerTask
    run::Union{Run{MC,DefaultRNG},Nothing}
end

function start(::Type{MPIRunner{MC}}, job::JobInfo) where {MC}
    JobTools.create_job_directory(job)
    MPI.Init()
    comm = MPI.COMM_WORLD

    rank = MPI.Comm_rank(comm)

    if rank == 0
        start(MPIRunnerController, job)
    else
        start(MPIRunnerWorker{MC}, job)
    end

    MPI.Barrier(comm)
    MPI.Finalize()

    return nothing
end

function start(::Type{MPIRunnerController}, job::JobInfo)
    controller = MPIRunnerController(job, MPI.Comm_size(MPI.COMM_WORLD))

    while controller.num_active_ranks > 1
        react!(controller)
    end

    all_done = controller.task_id === nothing
    @info "controller: stopping due to $(all_done ? "completion" : "time limit")"

    return !all_done
end

function react!(controller::MPIRunnerController)
    rank_status, status = MPI.Recv(
        MPIRunnerStatus,
        MPI.COMM_WORLD,
        MPI.Status;
        source = MPI.ANY_SOURCE,
        tag = T_STATUS,
    )
    rank = status.source

    if rank_status == S_IDLE
        controller.task_id = get_new_task_id(controller.tasks, controller.task_id)
        if controller.task_id === nothing
            send_action(A_EXIT, rank)
            controller.num_active_ranks -= 1
        else
            send_action(A_NEW_TASK, rank)
            task = controller.tasks[controller.task_id]
            task.scheduled_runs += 1

            sweeps_until_comm = 1 + max(0, task.target_sweeps - task.sweeps)
            msg = MPIRunnerNewJobResponse(
                controller.task_id,
                task.scheduled_runs,
                sweeps_until_comm,
            )

            MPI.Send(msg, MPI.COMM_WORLD; dest = rank, tag = T_NEW_TASK)
        end
    elseif rank_status == S_BUSY
        msg = MPI.Recv(
            MPIRunnerBusyResponse,
            MPI.COMM_WORLD;
            source = rank,
            tag = T_BUSY_STATUS,
        )

        task = controller.tasks[msg.task_id]
        task.sweeps += msg.sweeps_since_last_query
        if is_done(task)
            task.scheduled_runs -= 1
            if task.scheduled_runs > 0
                @info "$(basename(task.dir)) has enough sweeps. Waiting for $(task.scheduled_runs) busy ranks."
                send_action(A_NEW_TASK, rank)
            else
                @info "$(basename(task.dir)) is done. Merging."
                send_action(A_PROCESS_DATA_NEW_TASK, rank)
            end
        else
            send_action(A_CONTINUE, rank)
        end
    elseif rank_status == S_TIMEUP
        controller.num_active_ranks -= 1
    else
        error("Invalid rank status $(rank_status)")
    end

    return nothing
end

function start(::Type{MPIRunnerWorker{MC}}, job::JobInfo) where {MC}
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    worker::Union{MPIRunnerWorker{MC},Nothing} = nothing

    runner_task::Union{RunnerTask,Nothing} = nothing

    time_start = Dates.now()
    time_last_checkpoint = Dates.now()

    while true
        if worker === nothing
            action, msg = worker_signal_idle()
            if action == A_EXIT
                break
            end

            task = job.tasks[msg.task_id]
            runner_task =
                RunnerTask(msg.sweeps_until_comm, 0, JobTools.task_dir(job, task), 0)
            rundir = run_dir(runner_task, msg.run_id)

            run = read_checkpoint(Run{MC,DefaultRNG}, rundir, task.params)
            if run !== nothing
                @info "read $rundir"
            else
                run = Run{MC,DefaultRNG}(task.params)
                @info "initialized $rundir"
            end
            worker = MPIRunnerWorker{MC}(msg.task_id, msg.run_id, runner_task, run)
        end

        while !is_done(worker.task)
            worker.task.sweeps += step!(worker.run)

            if JobTools.is_checkpoint_time(job, time_last_checkpoint) ||
               JobTools.is_end_time(job, time_start)
                break
            end
        end

        write_checkpoint(worker)
        time_last_checkpoint = Dates.now()

        if JobTools.is_end_time(job, time_start)
            worker_signal_timeup()
            @info "rank $rank exits: time up"
            break
        end

        action = worker_signal_busy(worker.task_id, worker.task.sweeps)
        worker.task.target_sweeps -= worker.task.sweeps
        worker.task.sweeps = 0

        if action == A_PROCESS_DATA_NEW_TASK
            merge_results(
                MC,
                worker.task.dir;
                parameters = job.tasks[worker.task_id].params,
            )
            worker = nothing
        elseif action == A_NEW_TASK
            worker = nothing
        else
            @assert action == A_CONTINUE
        end
    end
end

worker_signal_timeup() = MPI.Send(S_TIMEUP, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)

function worker_signal_idle()
    MPI.Send(S_IDLE, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)
    new_action = recv_action()
    if new_action == A_EXIT
        return (A_EXIT, nothing)
    end

    msg = MPI.Recv(MPIRunnerNewJobResponse, MPI.COMM_WORLD; source = 0, tag = T_NEW_TASK)
    return (A_NEW_TASK, msg)
end

function worker_signal_busy(task_id::Integer, sweeps_since_last_query::Integer)
    MPI.Send(S_BUSY, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)
    msg = MPIRunnerBusyResponse(task_id, sweeps_since_last_query)
    MPI.Send(msg, MPI.COMM_WORLD; dest = 0, tag = T_BUSY_STATUS)
    new_action = recv_action()

    return new_action
end

function write_checkpoint(runner::MPIRunnerWorker)
    rundir = run_dir(runner.task, runner.run_id)
    write_checkpoint!(runner.run, rundir)
    write_checkpoint_finalize(rundir)
    @info "rank $(MPI.Comm_rank(MPI.COMM_WORLD)): checkpointing $rundir"

    return nothing
end
