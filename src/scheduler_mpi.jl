using Dates
using MPI
using HDF5
using .JobTools: JobInfo

@enum MPISchedulerAction begin
    A_INVALID = 0
    A_EXIT = 1
    A_CONTINUE = 2
    A_NEW_TASK = 3
    A_PROCESS_DATA_NEW_TASK = 4
end

send_action(comm::MPI.Comm, action::MPISchedulerAction, dest::Integer) =
    send(action, comm; dest = dest, tag = T_ACTION)
recv_action(comm::MPI.Comm) = recv(MPISchedulerAction, comm; source = 0, tag = T_ACTION)[1]

function send(data, comm; dest, tag)
    req = MPI.Isend(data, comm; dest, tag)
    while !MPI.Test(req)
        yield()
    end
    return nothing
end

function recv(::Type{T}, comm; source, tag) where {T}
    data = Ref{T}()
    req = MPI.Irecv!(data, comm; source = source, tag = tag)
    status = MPI.Status(0, 0, 0, 0, 0)

    while ((flag, status) = MPI.Test(req, MPI.Status); !flag)
        yield()
    end
    return data[], status
end

struct TaskInterruptedException <: Exception end

# Base.@sync only propagates errors once all tasks are done. We want
# to fail everything as soon as one task is broken. Possibly this is
# not completely bullet-proof, but good enough for now.
function sync_or_error(tasks::AbstractArray{Task})
    c = Channel(Inf)
    for t in tasks
        @async begin
            Base._wait(t)
            put!(c, t)
        end
    end
    for _ in eachindex(tasks)
        t = take!(c)
        if istaskfailed(t)
            for tother in tasks
                if tother != t
                    schedule(tother, TaskInterruptedException(); error = true)
                end
            end
            throw(TaskFailedException(t))
        end
    end
    close(c)
end

struct MPISchedulerNewJobResponse
    task_id::Int
    run_id::Int
    sweeps_until_comm::Int64
end

struct MPISchedulerBusyResponse
    task_id::Int
    sweeps_since_last_query::Int64
end

const T_STATUS = 4354
const T_BUSY_STATUS = 4355
const T_ACTION = 4356
const T_NEW_TASK = 4357

const T_MCCONTEXT = 4358

@enum MPISchedulerStatus begin
    S_IDLE = 9
    S_BUSY = 10
    S_TIMEUP = 11
end

struct MPIScheduler <: AbstractScheduler end

mutable struct MPISchedulerController <: AbstractScheduler
    num_active_ranks::Int

    task_id::Union{Int,Nothing}
    tasks::Vector{SchedulerTask}

    function MPISchedulerController(job::JobInfo, active_ranks::Integer)
        return new(
            active_ranks,
            length(job.tasks),
            map(
                x -> SchedulerTask(x.target_sweeps, x.sweeps, x.dir, 0),
                JobTools.read_progress(job),
            ),
        )
    end
end

mutable struct MPISchedulerWorker{MC<:AbstractMC}
    task_id::Int
    run_id::Int

    task::SchedulerTask
    run::Union{Run{MC,DefaultRNG},Nothing}
end

function start(::Type{MPIScheduler}, job::JobInfo)
    JobTools.create_job_directory(job)
    MPI.Init()
    comm = MPI.COMM_WORLD

    rank = MPI.Comm_rank(comm)
    num_ranks = MPI.Comm_size(comm)
    rc = false

    ranks_per_run = job.ranks_per_run == :all ? num_ranks : job.ranks_per_run

    if num_ranks % ranks_per_run != 0
        error(
            "Number of MPI ranks ($num_ranks) is not a multiple of ranks per run ($(ranks_per_run))!",
        )
    end
    run_comm = MPI.Comm_split(comm, rank ÷ ranks_per_run, 0)
    run_leader_comm = MPI.Comm_split(comm, is_run_leader(run_comm) ? 1 : nothing, 0)


    if rank == 0
        @info "starting job '$(job.name)'"
        if ranks_per_run != 1
            @info "running in parallel run mode with $(ranks_per_run) ranks per run"
        end

        t_work = @async start(MPISchedulerWorker{job.mc}, $job, $run_leader_comm, $run_comm)
        t_ctrl = @async (rc = start(MPISchedulerController, $job, $run_leader_comm))
        sync_or_error([t_work, t_ctrl])
        @info "controller: concatenating results"
        JobTools.concatenate_results(job)
    else
        start(MPISchedulerWorker{job.mc}, job, run_leader_comm, run_comm)
    end

    MPI.Barrier(comm)
    MPI.Finalize()

    return rc
end

function start(::Type{MPISchedulerController}, job::JobInfo, run_leader_comm::MPI.Comm)
    controller = MPISchedulerController(job, MPI.Comm_size(run_leader_comm))

    while controller.num_active_ranks > 0
        react!(controller, run_leader_comm)
    end

    all_done = controller.task_id === nothing
    @info "controller: stopping due to $(all_done ? "completion" : "time limit")"

    return !all_done
end

function controller_react_idle(
    controller::MPISchedulerController,
    run_leader_comm::MPI.Comm,
    rank::Integer,
)
    controller.task_id = get_new_task_id(controller.tasks, controller.task_id)
    if controller.task_id === nothing
        send_action(run_leader_comm, A_EXIT, rank)
        controller.num_active_ranks -= 1
    else
        send_action(run_leader_comm, A_NEW_TASK, rank)
        task = controller.tasks[controller.task_id]
        task.scheduled_runs += 1

        sweeps_until_comm = max(0, task.target_sweeps - task.sweeps)
        msg = MPISchedulerNewJobResponse(
            controller.task_id,
            task.scheduled_runs,
            sweeps_until_comm,
        )

        send(msg, run_leader_comm; dest = rank, tag = T_NEW_TASK)
    end

    return nothing
end

function controller_react_busy(
    controller::MPISchedulerController,
    run_leader_comm::MPI.Comm,
    rank::Integer,
)
    msg, _ =
        recv(MPISchedulerBusyResponse, run_leader_comm; source = rank, tag = T_BUSY_STATUS)

    task = controller.tasks[msg.task_id]
    task.sweeps += msg.sweeps_since_last_query
    if is_done(task)
        task.scheduled_runs -= 1
        if task.scheduled_runs > 0
            @info "$(basename(task.dir)) has enough sweeps. Waiting for $(task.scheduled_runs) busy ranks."
            send_action(run_leader_comm, A_NEW_TASK, rank)
        else
            @info "$(basename(task.dir)) is done. Merging."
            send_action(run_leader_comm, A_PROCESS_DATA_NEW_TASK, rank)
        end
    else
        send_action(run_leader_comm, A_CONTINUE, rank)
    end
    return nothing
end

function controller_react_timeup(controller::MPISchedulerController)
    controller.num_active_ranks -= 1
    return nothing
end


function react!(controller::MPISchedulerController, run_leader_comm::MPI.Comm)
    rank_status, status =
        recv(MPISchedulerStatus, run_leader_comm; source = MPI.ANY_SOURCE, tag = T_STATUS)
    rank = status.source

    if rank_status == S_IDLE
        controller_react_idle(controller, run_leader_comm, rank)
    elseif rank_status == S_BUSY
        controller_react_busy(controller, run_leader_comm, rank)
    elseif rank_status == S_TIMEUP
        controller_react_timeup(controller)
    else
        error("Invalid rank status $(rank_status)")
    end

    return nothing
end

function start(
    ::Type{MPISchedulerWorker{MC}},
    job::JobInfo,
    run_leader_comm::MPI.Comm,
    run_comm::MPI.Comm,
) where {MC}
    worker::Union{MPISchedulerWorker{MC},Nothing} = nothing

    scheduler_task::Union{SchedulerTask,Nothing} = nothing

    time_start = Dates.now()
    time_last_checkpoint = Dates.now()

    while true
        if worker === nothing
            action, msg = worker_signal_idle(run_leader_comm, run_comm)
            if action == A_EXIT
                break
            end

            task = job.tasks[msg.task_id]
            scheduler_task =
                SchedulerTask(msg.sweeps_until_comm, 0, JobTools.task_dir(job, task), 0)
            rundir = run_dir(scheduler_task, msg.run_id)

            run = read_checkpoint(Run{MC,DefaultRNG}, rundir, task.params, run_comm)
            if run !== nothing
                is_run_leader(run_comm) && @info "read $rundir"
            else
                run = Run{MC,DefaultRNG}(task.params, run_comm)
                is_run_leader(run_comm) && @info "initialized $rundir"
            end
            worker = MPISchedulerWorker{MC}(msg.task_id, msg.run_id, scheduler_task, run)
        end

        while !is_done(worker.task)
            worker.task.sweeps += step!(worker.run, run_comm)

            if JobTools.is_checkpoint_time(job, time_last_checkpoint) ||
               JobTools.is_end_time(job, time_start)
                break
            end
        end

        write_checkpoint(worker, run_comm)
        time_last_checkpoint = Dates.now()

        if JobTools.is_end_time(job, time_start)
            worker_signal_timeup(run_leader_comm, run_comm)
            @info "rank $rank exits: time up"
            break
        end

        action = worker_signal_busy(
            run_leader_comm,
            run_comm,
            worker.task_id,
            worker.task.sweeps,
        )
        worker.task.target_sweeps -= worker.task.sweeps
        worker.task.sweeps = 0

        if action == A_PROCESS_DATA_NEW_TASK
            if is_run_leader(run_comm)
                merge_results(
                    MC,
                    worker.task.dir;
                    parameters = job.tasks[worker.task_id].params,
                )
            end
            worker = nothing
        elseif action == A_NEW_TASK
            worker = nothing
        else
            @assert action == A_CONTINUE
        end
    end
end

is_run_leader(run_comm::MPI.Comm) = MPI.Comm_rank(run_comm) == 0

function worker_signal_timeup(run_leader_comm::MPI.Comm, run_comm::MPI.Comm)
    if is_run_leader(run_comm)
        send(S_TIMEUP, run_leader_comm; dest = 0, tag = T_STATUS)
    end
end

function worker_signal_idle(run_leader_comm::MPI.Comm, run_comm::MPI.Comm)
    new_action = Ref{MPISchedulerAction}()
    if is_run_leader(run_comm)
        send(S_IDLE, run_leader_comm; dest = 0, tag = T_STATUS)
        new_action[] = recv_action(run_leader_comm)
    end
    MPI.Bcast!(new_action, 0, run_comm)

    if new_action[] == A_EXIT
        return (A_EXIT, nothing)
    end

    @assert new_action[] == A_NEW_TASK

    msg = Ref{MPISchedulerNewJobResponse}()
    if is_run_leader(run_comm)
        msg[], _ =
            recv(MPISchedulerNewJobResponse, run_leader_comm; source = 0, tag = T_NEW_TASK)
    end
    MPI.Bcast!(msg, run_comm)
    return (A_NEW_TASK, msg[])
end

function worker_signal_busy(
    run_leader_comm::MPI.Comm,
    run_comm::MPI.Comm,
    task_id::Integer,
    sweeps_since_last_query::Integer,
)
    new_action = Ref{MPISchedulerAction}()
    if is_run_leader(run_comm)
        send(S_BUSY, run_leader_comm; dest = 0, tag = T_STATUS)
        msg = MPISchedulerBusyResponse(task_id, sweeps_since_last_query)
        send(msg, run_leader_comm; dest = 0, tag = T_BUSY_STATUS)
        new_action[] = recv_action(run_leader_comm)
    end

    MPI.Bcast!(new_action, 0, run_comm)

    return new_action[]
end

function write_checkpoint(scheduler::MPISchedulerWorker, run_comm::MPI.Comm)
    rundir = run_dir(scheduler.task, scheduler.run_id)
    write_checkpoint!(scheduler.run, rundir, run_comm)
    if is_run_leader(run_comm)
        write_checkpoint_finalize(rundir)
        @info "rank $(MPI.Comm_rank(MPI.COMM_WORLD)): checkpointing $rundir"
    end

    return nothing
end
