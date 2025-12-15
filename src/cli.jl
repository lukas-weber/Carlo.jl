using PrecompileTools

include("tinyargparse.jl")

"""
    start(job::JobInfo, ARGS)

Call this from your job script to start the Carlo command line interface.

If for any reason you do not want to use job scripts, you can directly schedule a job using

    start(Carlo.MPIScheduler, job)
"""
function start(job::JobInfo, args::AbstractVector{<:AbstractString})
    AP = TinyArgParse
    commands = [
        AP.Command(
            "run",
            "r",
            "Starts a simulation",
            [
                AP.Option("single", "s", "Run in single core mode"),
                AP.Option("restart", "r", "Delete existing files and start from scratch"),
                AP.help(),
            ],
        ),
        AP.Command("status", "s", "Check the progress of a simulation", [AP.help()]),
        AP.Command("merge", "m", "Merge results of an incomplete simulation", [AP.help()]),
        AP.Command("delete", "d", "Clean up a simulation directory", [AP.help()]),
    ]
    general_args = [AP.help()]

    cmd, general, specific = nothing, nothing, nothing
    try
        cmd, general, specific = AP.parse(commands, general_args, args)
    catch e
        if e isa AP.Error
            showerror(stderr, e)
            return nothing
        else
            rethrow(e)
        end
    end

    if AP.handle_help(cmd, general, specific)
        return nothing
    end
    if isnothing(cmd)
        println(stderr, "No command given")
        AP.print_help(stdout, commands, general_args)
        return nothing
    end


    cmd_funcs = Dict(
        "run" => cli_run,
        "merge" => cli_merge,
        "status" => cli_status,
        "delete" => cli_delete,
    )

    return cmd_funcs[cmd](job, specific)
end

function cli_run(job::JobInfo, args::AbstractDict)
    if haskey(args, "restart")
        if haskey(args, "single") || (MPI.Init(); MPI.Comm_rank(MPI.COMM_WORLD)) == 0
            cli_delete(job, Dict())
        end
    end
    MPI.Init()
    MPI.Barrier(MPI.COMM_WORLD)

    scheduler = haskey(args, "single") ? SingleScheduler : MPIScheduler
    if scheduler == MPIScheduler && MPI.Comm_size(MPI.COMM_WORLD) == 1
        @info "running with a single process: defaulting to --single scheduler"
        scheduler = SingleScheduler
    end

    return with_logger(default_logger()) do
        start(scheduler, job)
    end
end

function cli_status(job::JobInfo, ::AbstractDict)
    try
        tasks = JobTools.read_progress(job)

        if isempty(tasks)
            return true
        end

        data = permutedims(
            reduce(
                hcat,
                [
                    basename(x.dir),
                    x.sweeps,
                    x.target_sweeps,
                    x.num_runs,
                    "$(round(Int,100*x.thermalization_fraction))%",
                ] for x in tasks
            ),
        )
        column_labels = ["task", "sweeps", "target", "runs", "thermalized"]
        print_table(string.(data); column_labels)
        return all(map(x -> x.sweeps >= x.target_sweeps, tasks))
    catch err
        if isa(err, Base.IOError)
            @error "Could not read job progress. Not run yet?"
            exit(1)
        else
            rethrow(err)
        end
    end
end

function cli_delete(job::JobInfo, ::AbstractDict)
    rm("$(job.dir)/../$(job.name).results.json"; force = true)
    rm(job.dir; recursive = true, force = true)

    return nothing
end

function cli_merge(job::JobInfo, ::AbstractDict)
    for task in job.tasks
        merge_results(job.mc, JobTools.task_dir(job, task); parameters = task.params)
    end
    JobTools.concatenate_results(job)
    return nothing
end

function print_table(data::AbstractMatrix{<:AbstractString}; column_labels)
    column_widths = map(column_labels, eachcol(data)) do label, col
        return max(length(label), maximum(length, col))
    end

    divider = repeat("─", sum(column_widths) + 2 * length(column_widths))

    println(divider)
    println(
        " " * join(
            (lpad(label, width) for (label, width) in zip(column_labels, column_widths)),
            "  ",
        ),
    )
    println(divider)

    for row in eachrow(data)
        println(
            " " *
            join((lpad(label, width) for (label, width) in zip(row, column_widths)), "  "),
        )
    end
    println(divider)
end
