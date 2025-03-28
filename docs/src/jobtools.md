# [JobTools](@id jobtools)

This submodule contains tools to specify or read job information necessary to run Carlo calculations.
```@docs
JobInfo
TaskInfo
result_filename
run_time_from_slurm
start(job::JobInfo,::AbstractVector{<:AbstractString})
```

## TaskMaker
```@docs
TaskMaker
task
make_tasks
current_task_name
```
