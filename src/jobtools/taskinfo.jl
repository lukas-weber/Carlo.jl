using HDF5

"""
    TaskInfo(name::AbstractString, params::Dict{Symbol,Any})

Holds information of one parameter set in a Monte Carlo calculation. While it is possible to construct it by hand, for multiple tasks, it is recommended to
use [`TaskMaker`](@ref) for convenience.

# Special parameters
While `params` can hold any kind of parameter, some are special and used to configure the behavior of LoadLeveller.

- `sweeps`: *required*. The minimum number of Monte Carlo measurement sweeps to perform for the task.
- `thermalization`: *required*. The number of thermalization sweeps to perform.
- `binsize`: *required*. The internal default binsize for observables. LoadLeveller will merge this many samples into one bin before saving them.
    On top of this, a rebinning analysis is performed, so that this setting mostly affects disk space and IO efficiency. To get correct autocorrelation times, it should be 1. In all other cases much higher.

- `rng`: *optional*. Type of the random number generator to use. See [rng](@ref).
- `seed`: *optional*. Optionally run calculations with a fixed seed. Useful for debugging.
- `float_type`: *optional*. Type of floating point numbers to use for the measurement postprocessing. Default: Float64.

Out of these parameters, it is only permitted to change `sweeps` for an existing calculation. This is handy to run the simulation for longer or shorter than planned originally.
"""
struct TaskInfo
    name::String
    params::Dict{Symbol,Any}

    function TaskInfo(name::AbstractString, params::AbstractDict)
        required_keys = [:sweeps, :thermalization, :binsize]
        if !(required_keys ⊆ keys(params))
            error(
                "task $name missing required parameters $(setdiff(required_keys, keys(params)))",
            )
        end

        return new(name, params)
    end
end

function task_name(task_id::Integer)
    return format("task{:04d}", task_id)
end

function list_run_files(taskdir::AbstractString, ending::AbstractString)
    return map(
        x -> taskdir * "/" * x,
        filter(x -> occursin(Regex("^run\\d{4,}\\.$ending\$"), x), readdir(taskdir)),
    )
end

function read_dump_progress(taskdir::AbstractString)
    sweeps = Tuple{Int64,Int64}[]
    for dumpname in list_run_files(taskdir, "dump\\.h5")
        h5open(dumpname, "r") do f
            push!(
                sweeps,
                (
                    read(f["context/0001/sweeps"], Int64),
                    read(f["context/0001/thermalization_sweeps"], Int64),
                ),
            )
        end
    end
    return sweeps
end

struct TaskProgress
    target_sweeps::Int64
    sweeps::Int64
    num_runs::Int64
    thermalization_fraction::Float64
    dir::String
end
