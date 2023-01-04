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

mutable struct MPIRunnerMaster <: AbstractRunner
    num_active_ranks::Int32

    task_id::Union{Int32,Nothing}
    tasks::Vector{RunnerTask}

    function MPIRunnerMaster(job::JobInfo, active_ranks::Integer)
        return new(active_ranks, 1, map(x->RunnerTask(x[:target_sweeps], x[:sweeps], x[:dir], 0), JobTools.read_progress(job)))
    end
end

mutable struct MPIRunnerSlave{MC<:AbstractMC}
    task_id::Int32
    run_id::Int32

    task::RunnerTask
    walker::Union{Walker{MC,DefaultRNG},Nothing}
end

function start(::Type{MPIRunner{MC}}, job::JobInfo) where {MC}
    MPI.Init()
    comm = MPI.COMM_WORLD

    rank = MPI.Comm_rank(comm)

    if rank == 0
        start(MPIRunnerMaster, job)
    else
        start(MPIRunnerSlave{MC}, job)
    end

    MPI.Barrier(comm)
    MPI.Finalize()

    return nothing
end

function start(::Type{MPIRunnerMaster}, job::JobInfo)
    master = MPIRunnerMaster(job, MPI.Comm_size(MPI.COMM_WORLD))

    while master.num_active_ranks > 1
        react!(master)
    end

    all_done = master.task_id === nothing
    @info "master: stopping due to $(all_done ? "completion" : "time limit")"

    return !all_done
end

function react!(master::MPIRunnerMaster)
    rank_status, status = MPI.Recv(
        MPIRunnerStatus,
        MPI.COMM_WORLD,
        MPI.Status;
        source = MPI.ANY_SOURCE,
        tag = T_STATUS,
    )
    rank = status.source

    if rank_status == S_IDLE
        master.task_id = get_new_task_id(master.tasks, master.task_id)
        if master.task_id === nothing
            send_action(A_EXIT, rank)
            master.num_active_ranks -= 1
        else
            send_action(A_NEW_TASK, rank)
            task = master.tasks[master.task_id]
            task.scheduled_runs += 1

            sweeps_until_comm = 1 + max(0, task.target_sweeps - task.sweeps)
            msg = MPIRunnerNewJobResponse(
                master.task_id,
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

        task = master.tasks[msg.task_id]
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
        master.num_active_ranks -= 1
    else
        error("Invalid rank status $(rank_status)")
    end

    return nothing
end

function start(::Type{MPIRunnerSlave{MC}}, job::JobInfo) where {MC}
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    slave::Union{MPIRunnerSlave{MC},Nothing} = nothing

    runner_task::Union{RunnerTask,Nothing} = nothing

    time_start = Dates.now()
    time_last_checkpoint = Dates.now()

    while true
        if slave === nothing
            action, msg = slave_signal_idle()
            if action == A_EXIT
                break
            end

            task = job.tasks[msg.task_id]
            runner_task = RunnerTask(msg.sweeps_until_comm, 0, JobTools.task_dir(job, task), 0)
            walkerdir = walker_dir(runner_task, msg.run_id)

            walker = read_checkpoint(Walker{MC,DefaultRNG}, walkerdir, task.params)
            if walker !== nothing
                @info "read $walkerdir"
            else
                walker = Walker{MC,DefaultRNG}(task.params)
                @info "initialized $walkerdir"
            end
            slave = MPIRunnerSlave{MC}(msg.task_id, msg.run_id, runner_task, walker)
        end

        while !is_done(slave.task)
            slave.task.sweeps += step!(slave.walker)

            if JobTools.is_checkpoint_time(job, time_last_checkpoint) || JobTools.is_end_time(job, time_start)
                break
            end
        end

        write_checkpoint(slave)
        time_last_checkpoint = Dates.now()

        if JobTools.is_end_time(job, time_start)
            slave_signal_timeup()
            @info "rank $rank exits: time up"
            break
        end

        action = slave_signal_busy(slave.task_id, slave.task.sweeps)
        slave.task.target_sweeps -= slave.task.sweeps
        slave.task.sweeps = 0

        if action == A_PROCESS_DATA_NEW_TASK
            merge_results(MC, slave.task; parameters = job.tasks[slave.task_id].params)
            slave = nothing
        elseif action == A_NEW_TASK
            slave = nothing
        else
            @assert action == A_CONTINUE
        end
    end
end

slave_signal_timeup() = MPI.Send(S_TIMEUP, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)

function slave_signal_idle()
    MPI.Send(S_IDLE, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)
    new_action = recv_action()
    if new_action == A_EXIT
        return (A_EXIT, nothing)
    end

    msg = MPI.Recv(MPIRunnerNewJobResponse, MPI.COMM_WORLD; source = 0, tag = T_NEW_TASK)
    return (A_NEW_TASK, msg)
end

function slave_signal_busy(task_id::Integer, sweeps_since_last_query::Integer)
    MPI.Send(S_BUSY, MPI.COMM_WORLD; dest = 0, tag = T_STATUS)
    msg = MPIRunnerBusyResponse(task_id, sweeps_since_last_query)
    MPI.Send(msg, MPI.COMM_WORLD; dest = 0, tag = T_BUSY_STATUS)
    new_action = recv_action()

    return new_action
end

function write_checkpoint(runner::MPIRunnerSlave)
    walkerdir = walker_dir(runner.task, runner.run_id)
    write_checkpoint!(runner.walker, walkerdir)
    write_checkpoint_finalize(walkerdir)
    @info "rank $(MPI.Comm_rank(MPI.COMM_WORLD)): checkpointing $walkerdir"

    return nothing
end
