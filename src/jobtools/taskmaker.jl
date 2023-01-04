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

function make_tasks(tm::TaskMaker)
    return Base.getfield(tm, :tasks)
end
