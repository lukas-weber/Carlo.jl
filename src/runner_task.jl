mutable struct RunnerTask
    target_sweeps::Int64
    sweeps::Int64
    scheduled_runs::Int64
end

is_done(task::RunnerTask) = task.sweeps >= task.target_sweeps
