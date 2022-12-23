
struct TaskInfo
    name::String
    params::Dict{Symbol,Any}
end

function task_name(task_id::Integer)
    return format("task{:04d}", task_id)
end