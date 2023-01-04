using HDF5

struct TaskInfo
    name::String
    params::Dict{Symbol,Any}
end

function task_name(task_id::Integer)
    return format("task{:04d}", task_id)
end

function list_walker_files(taskdir::AbstractString, ending::AbstractString)
    return map(
        x -> taskdir * "/" * x,
        filter(x -> occursin(Regex("^walker\\d{4,}\\.$ending\$"), x), readdir(taskdir)),
    )
end

function read_dump_progress(taskdir::AbstractString)
    return mapreduce(
        +,
        list_walker_files(taskdir, "dump\\.h5"),
        init = Int64(0),
    ) do dumpname
        sweeps = 0
        h5open(dumpname, "r") do f
            sweeps =
                max(0, read(f["context/sweeps"]) - read(f["context/thermalization_sweeps"]))
        end
        return sweeps
    end
end
