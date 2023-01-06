"""
    TaskMaker()

Tool for generating a list of tasks, i.e. parameter sets, to be simulated in a Monte Carlo simulation.

The fields of `TaskMaker` can be freely assigned and each time [`task`](@ref) is called, their current state will be copied into a new task.
Finally the list of tasks can be generated using [`make_tasks`](@ref)

# Example
The following example creates a list of 11 tasks for different parameters "`T`". The first task will be run with more sweeps than the rest.
```julia
tm = TaskMaker()
tm.sweeps = 10000
tm.thermalization = 2000
tm.binsize = 500

task(tm; T=0.04)
tm.sweeps = 5000
for T in range(0.1, 10, length=10)
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
    task(tm::TaskMaker; kwargs...)

Creates a new task for the current set of parameters saved in `tm`. Optionally, `kwargs` can be used to specify parameters that are set for this task only.
"""
function task(tm::TaskMaker; kwargs...)
    taskname = task_name(length(Base.getfield(tm, :tasks)) + 1)

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
