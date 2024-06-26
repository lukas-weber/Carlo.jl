"""
    TaskMaker()

Tool for generating a list of tasks, i.e. parameter sets, to be simulated in a Monte Carlo simulation.

The fields of `TaskMaker` can be freely assigned and each time [`task`](@ref) is called, their current state will be copied into a new task.
Finally the list of tasks can be generated using [`make_tasks`](@ref)

In most cases the resulting tasks will be used in the constructor of [`JobInfo`](@ref), the basic description for jobs in Carlo.

# Example
The following example creates a list of 5 tasks for different parameters `T`. This could be a scan of the finite-temperature phase diagram of some model. The first task will be run with more sweeps than the rest.
```@example
tm = TaskMaker()
tm.sweeps = 10000
tm.thermalization = 2000
tm.binsize = 500

task(tm; T=0.04)
tm.sweeps = 5000
for T in range(0.1, 10, length=5)
    task(tm; T=T)
end

tasks = make_tasks(tm)
```
"""
mutable struct TaskMaker
    tasks::Vector{TaskInfo}
    current_task_params::Dict{Symbol,Any}
    TaskMaker() = new([], Dict{Symbol,Any}())
end

function Base.setproperty!(tm::TaskMaker, symbol::Symbol, value)
    Base.getfield(tm, :current_task_params)[symbol] = value
    return nothing
end

function Base.getproperty(tm::TaskMaker, symbol::Symbol)
    return Base.getfield(tm, :current_task_params)[symbol]
end

"""
    current_task_name(tm::TaskMaker)

Returns the name of the task that will be created by `task(tm)`.
"""
function current_task_name(tm::TaskMaker)
    return task_name(length(Base.getfield(tm, :tasks)) + 1)
end

"""
    task(tm::TaskMaker; kwargs...)

Creates a new task for the current set of parameters saved in `tm`. Optionally, `kwargs` can be used to specify parameters that are set for this task only.
"""
function task(tm::TaskMaker; kwargs...)
    taskname = current_task_name(tm)

    append!(
        Base.getfield(tm, :tasks),
        [
            TaskInfo(
                taskname,
                merge(Base.getfield(tm, :current_task_params), Dict{Symbol,Any}(kwargs)),
            ),
        ],
    )

    return nothing
end

"""
    make_tasks(tm::TaskMaker)::Vector{TaskInfo}

Generate a list of tasks from `tm` based on the previous calls of [`task`](@ref). The output of this will typically be supplied to the `tasks` argument of
[`JobInfo`](@ref).
"""
function make_tasks(tm::TaskMaker)
    return Base.getfield(tm, :tasks)
end
