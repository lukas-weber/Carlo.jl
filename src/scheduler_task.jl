mutable struct SchedulerTask
    target_sweeps::Int64
    sweeps::Int64
    thermalization::Int64 # used for scheduling estimates only

    dir::String
    scheduled_runs::Int64
    max_scheduled_runs::Int64
end

SchedulerTask(
    target_sweeps::Integer,
    sweeps::Integer,
    thermalization::Integer,
    dir::AbstractString,
) = SchedulerTask(target_sweeps, sweeps, thermalization, dir, 0, typemax(Int64))

is_done(task::SchedulerTask) = task.sweeps >= task.target_sweeps

function run_dir(task::SchedulerTask, run_id::Integer)
    return @sprintf "%s/run%04d" task.dir run_id
end
