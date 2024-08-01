using Dates
using MPI
using HDF5
using .JobTools: JobInfo

@enum MPISchedulerAction begin
    A_INVALID = 0x00
    A_EXIT = 0x01
    A_CONTINUE = 0x02
    A_NEW_TASK = 0x03
    A_PROCESS_DATA_NEW_TASK = 0x04
end

function warn_if_controller_slow(delay::Real)
    if delay > 0.5
        @warn "controller took a long time to respond: $delay"
    end
end

struct TaskInterruptedException <: Exception end

struct MPISchedulerIdleResponse
    action::MPISchedulerAction
    task_id::Int
    run_id::Int
    sweeps_until_comm::Int64
end

MPISchedulerIdleResponse(action::MPISchedulerAction) =
    MPISchedulerIdleResponse(action, 0, 0, 0)

struct MPISchedulerBusyResponse
    action::MPISchedulerAction
    sweeps_until_comm::Int64
end
MPISchedulerBusyResponse(action::MPISchedulerAction) = MPISchedulerBusyResponse(action, 0)

struct MPISchedulerBusyRequest
    task_id::Int
    sweeps_since_last_query::Int64
end

const T_STATUS_REQUEST = 4355
const T_IDLE_RESPONSE = 4356
const T_BUSY_REQUEST = 4357
const T_BUSY_RESPONSE = 4358

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
end

MPISchedulerController(job::JobInfo, active_ranks::Integer) = MPISchedulerController(
    active_ranks,
    length(job.tasks),
    [
        SchedulerTask(
            p.target_sweeps,
            p.sweeps,
            t.params[:thermalization],
            p.dir,
            0,
            get(t.params, :max_runs_per_task, typemax(Int64)),
        ) for (p, t) in zip(JobTools.read_progress(job), job.tasks)
    ],
)

mutable struct MPISchedulerWorker
    task_id::Int
    run_id::Int

    task::SchedulerTask
    run::Union{Run,Nothing}
end

function start(::Type{MPIScheduler}, job::JobInfo)
    JobTools.create_job_directory(job)
    MPI.Init()
    comm = MPI.COMM_WORLD

    rank = MPI.Comm_rank(comm)
    num_ranks = MPI.Comm_size(comm)
    rc = false

    if num_ranks == 1
        @error "started MPIScheduler with a single rank, but at least two are required for doing any work. Use SingleScheduler instead."
    end

    ranks_per_run = job.ranks_per_run == :all ? num_ranks - 1 : job.ranks_per_run

    if (num_ranks - 1) % ranks_per_run != 0
        error(
            "Number of MPI worker ranks ($num_ranks - 1 = $(num_ranks-1)) is not a multiple of ranks per run ($(ranks_per_run))!",
        )
    end
    run_comm = MPI.Comm_split(comm, rank == 0 ? 0 : 1 + (rank - 1) ÷ ranks_per_run, 0)
    run_leader_comm = MPI.Comm_split(comm, is_run_leader(run_comm) ? 1 : nothing, 0)

    if rank == 0
        @info "starting job '$(job.name)'"
        if ranks_per_run != 1
            @info "running in parallel run mode with $(ranks_per_run) ranks per run"
        end

        rc = start(MPISchedulerController, job, run_leader_comm)
        @info "controller: concatenating results"
        JobTools.concatenate_results(job)
    else
        start(MPISchedulerWorker, job, run_leader_comm, run_comm)
    end

    MPI.Barrier(comm)
    # MPI.Finalize()

    return rc
end

function start(::Type{MPISchedulerController}, job::JobInfo, run_leader_comm::MPI.Comm)
    controller = MPISchedulerController(job, MPI.Comm_size(run_leader_comm) - 1)

    while controller.num_active_ranks > 0
        react!(controller, run_leader_comm)
    end

    all_done = controller.task_id === nothing
    @info "controller: stopping due to $(all_done ? "completion" : "time limit")"

    return !all_done
end

function get_new_task_id_with_significant_work(
    tasks::AbstractVector{<:SchedulerTask},
    task_id::Union{Nothing,Integer},
)
    for _ in eachindex(tasks)
        task_id = get_new_task_id(tasks, task_id)

        if task_id === nothing
            return nothing
        end

        task = tasks[task_id]
        if task.target_sweeps - task.sweeps >
           max(task.thermalization * task.scheduled_runs, task.scheduled_runs)
            return task_id
        end
    end
    return nothing
end

function controller_react_idle(
    controller::MPISchedulerController,
    run_leader_comm::MPI.Comm,
    rank::Integer,
)
    controller.task_id =
        get_new_task_id_with_significant_work(controller.tasks, controller.task_id)
    if controller.task_id === nothing
        MPI.Send(
            MPISchedulerIdleResponse(A_EXIT),
            run_leader_comm;
            dest = rank,
            tag = T_IDLE_RESPONSE,
        )
        controller.num_active_ranks -= 1
    else
        task = controller.tasks[controller.task_id]
        task.scheduled_runs += 1

        @assert controller.num_active_ranks > 0
        sweeps_until_comm = clamp(
            (task.target_sweeps - task.sweeps) ÷ task.scheduled_runs,
            0,
            task.target_sweeps ÷ controller.num_active_ranks,
        )
        MPI.Send(
            MPISchedulerIdleResponse(
                A_NEW_TASK,
                controller.task_id,
                task.scheduled_runs,
                sweeps_until_comm,
            ),
            run_leader_comm;
            dest = rank,
            tag = T_IDLE_RESPONSE,
        )
    end

    return nothing
end

function controller_react_busy(
    controller::MPISchedulerController,
    run_leader_comm::MPI.Comm,
    rank::Integer,
)
    msg = MPI.Recv(
        MPISchedulerBusyRequest,
        run_leader_comm;
        source = rank,
        tag = T_BUSY_REQUEST,
    )

    task = controller.tasks[msg.task_id]
    task.sweeps += msg.sweeps_since_last_query
    if is_done(task)
        task.scheduled_runs -= 1
        if task.scheduled_runs > 0
            @info "$(basename(task.dir)) has enough sweeps. Waiting for $(task.scheduled_runs) busy ranks."
            MPI.Send(
                MPISchedulerBusyResponse(A_NEW_TASK),
                run_leader_comm;
                dest = rank,
                tag = T_BUSY_RESPONSE,
            )
        else
            @info "$(basename(task.dir)) is done. Merging."
            MPI.Send(
                MPISchedulerBusyResponse(A_PROCESS_DATA_NEW_TASK),
                run_leader_comm;
                dest = rank,
                tag = T_BUSY_RESPONSE,
            )
        end
    else
        sweeps_until_comm = clamp(
            (task.target_sweeps - task.sweeps) ÷ task.scheduled_runs,
            1,
            max(1, task.target_sweeps ÷ controller.num_active_ranks),
        )
        MPI.Send(
            MPISchedulerBusyResponse(A_CONTINUE, sweeps_until_comm),
            run_leader_comm;
            dest = rank,
            tag = T_BUSY_RESPONSE,
        )
    end
    return nothing
end

function controller_react_timeup(controller::MPISchedulerController)
    controller.num_active_ranks -= 1
    return nothing
end


function react!(controller::MPISchedulerController, run_leader_comm::MPI.Comm)
    rank_status, status = MPI.Recv(
        MPISchedulerStatus,
        run_leader_comm,
        MPI.Status;
        source = MPI.ANY_SOURCE,
        tag = T_STATUS_REQUEST,
    )
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
    ::Type{MPISchedulerWorker},
    job::JobInfo,
    run_leader_comm::MPI.Comm,
    run_comm::MPI.Comm,
)
    worker::Union{MPISchedulerWorker,Nothing} = nothing

    scheduler_task::Union{SchedulerTask,Nothing} = nothing

    time_start = Dates.now()
    time_last_checkpoint = Dates.now()

    while true
        if worker === nothing
            response = worker_signal_idle(run_leader_comm, run_comm)
            if response.action == A_EXIT
                break
            end

            task = job.tasks[response.task_id]
            scheduler_task = SchedulerTask(
                response.sweeps_until_comm,
                0,
                task.params[:thermalization],
                JobTools.task_dir(job, task),
            )
            rundir = run_dir(scheduler_task, response.run_id)

            run = read_checkpoint(Run{job.mc,job.rng}, rundir, task.params, run_comm)
            if run !== nothing
                is_run_leader(run_comm) && @info "read $rundir"
            else
                run = Run{job.mc,job.rng}(task.params, run_comm)
                is_run_leader(run_comm) && @info "initialized $rundir"
            end
            worker =
                MPISchedulerWorker(response.task_id, response.run_id, scheduler_task, run)
            time_last_checkpoint = Dates.now()
        end

        timeup = Ref(false)
        while !is_done(worker.task)
            worker.task.sweeps += step!(worker.run, run_comm)
            yield()

            timeup[] =
                JobTools.is_checkpoint_time(job, time_last_checkpoint) ||
                JobTools.is_end_time(job, time_start)
            MPI.Bcast!(timeup, 0, run_comm)
            if timeup[]
                break
            end
        end

        if JobTools.is_end_time(job, time_start)
            worker_signal_timeup(run_leader_comm, run_comm)
            @info "exits: time up"
            break
        end

        response = worker_signal_busy(
            run_leader_comm,
            run_comm,
            worker.task_id,
            worker.task.sweeps,
        )
        worker.task.target_sweeps -= worker.task.sweeps
        worker.task.sweeps = 0

        if response.action == A_PROCESS_DATA_NEW_TASK
            write_checkpoint(worker, run_comm)

            if is_run_leader(run_comm)
                merge_results(
                    job.mc,
                    worker.task.dir;
                    parameters = job.tasks[worker.task_id].params,
                )
            end
            worker = nothing
        elseif response.action == A_NEW_TASK
            write_checkpoint(worker, run_comm)
            worker = nothing
        else
            if timeup[]
                write_checkpoint(worker, run_comm)
                time_last_checkpoint = Dates.now()
            end

            @assert response.action == A_CONTINUE
            worker.task.target_sweeps = response.sweeps_until_comm
            @assert !is_done(worker.task)
        end
    end
end

is_run_leader(run_comm::MPI.Comm) = MPI.Comm_rank(run_comm) == 0

function worker_signal_timeup(run_leader_comm::MPI.Comm, run_comm::MPI.Comm)
    if is_run_leader(run_comm)
        MPI.Send(S_TIMEUP, run_leader_comm; dest = 0, tag = T_STATUS_REQUEST)
    end
end

function worker_signal_idle(run_leader_comm::MPI.Comm, run_comm::MPI.Comm)
    response = Ref{MPISchedulerIdleResponse}()
    if is_run_leader(run_comm)
        delay = @elapsed begin
            MPI.Send(S_IDLE, run_leader_comm; dest = 0, tag = T_STATUS_REQUEST)
            response[] = MPI.Recv(
                MPISchedulerIdleResponse,
                run_leader_comm;
                source = 0,
                tag = T_IDLE_RESPONSE,
            )
        end
        warn_if_controller_slow(delay)
    end
    MPI.Bcast!(response, 0, run_comm)

    return response[]
end

function worker_signal_busy(
    run_leader_comm::MPI.Comm,
    run_comm::MPI.Comm,
    task_id::Integer,
    sweeps_since_last_query::Integer,
)
    response = Ref{MPISchedulerBusyResponse}()
    if is_run_leader(run_comm)
        MPI.Send(S_BUSY, run_leader_comm; dest = 0, tag = T_STATUS_REQUEST)
        MPI.Send(
            MPISchedulerBusyRequest(task_id, sweeps_since_last_query),
            run_leader_comm;
            dest = 0,
            tag = T_BUSY_REQUEST,
        )
        response[] = MPI.Recv(
            MPISchedulerBusyResponse,
            run_leader_comm;
            source = 0,
            tag = T_BUSY_RESPONSE,
        )
    end

    MPI.Bcast!(response, 0, run_comm)

    return response[]
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
