mutable struct SchedulerTask
    target_sweeps::Int64
    sweeps::Int64

    dir::String
    scheduled_runs::Int64
    max_scheduled_runs::Int64
end

SchedulerTask(target_sweeps::Integer, sweeps::Integer, dir::AbstractString) =
    SchedulerTask(target_sweeps, sweeps, dir, 0, typemax(Int64))

is_done(task::SchedulerTask) = task.sweeps >= task.target_sweeps

function run_dir(task::SchedulerTask, run_id::Integer)
    return @sprintf "%s/run%04d" task.dir run_id
end
