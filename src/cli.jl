using ArgParse
using PrecompileTools
using PrettyTables

"""
    start(job::JobInfo, ARGS)

Call this from your job script to start the LoadLeveller command line interface.

If for any reason you do not want to use job scripts, you can directly schedule a job using

    start(LoadLeveller.MPIRunner, job)
"""
function start(job::JobInfo, args::AbstractVector{<:AbstractString})
    s = ArgParseSettings()
    @add_arg_table! s begin
        "run", "r"
        help = "Starts a simulation"
        action = :command
        "status", "s"
        help = "Check the progress of a simulation"
        action = :command
        "merge", "m"
        help = "Merge results of an incomplete simulation"
        action = :command
        "delete", "d"
        help = "Clean up a simulation directory"
        action = :command
    end

    @add_arg_table! s["run"] begin
        "--single", "-s"
        help = "run in single core mode"
        action = :store_true
        "--restart", "-r"
        help = "delete existing files and start from scratch"
        action = :store_true
    end

    parsed_args = parse_args(args, s)
    cmd = parsed_args["%COMMAND%"]

    cmd_funcs = Dict(
        "run" => cli_run,
        "merge" => cli_merge,
        "status" => cli_status,
        "delete" => cli_delete,
    )

    return cmd_funcs[cmd](job, parsed_args[cmd])
end

function cli_run(job::JobInfo, args::AbstractDict)
    if args["restart"]
        if args["single"] || (MPI.Init(); MPI.Comm_rank(MPI.COMM_WORLD)) == 0
            cli_delete(job, Dict())
        end
    end

    runner = args["single"] ? SingleRunner : MPIRunner
    return start(runner, job)
end

function cli_status(job::JobInfo, ::AbstractDict)
    try
        tasks = JobTools.read_progress(job)

        data = permutedims(
            hcat(
                (
                    [
                        basename(x.dir),
                        x.sweeps,
                        x.target_sweeps,
                        x.num_runs,
                        "$(round(Int,100*x.thermalization_fraction))%",
                    ] for x in tasks
                )...,
            ),
        )
        header = ["task", "sweeps", "target", "runs", "thermalized"]
        pretty_table(data, vlines = :none, header = header)
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
        merge_results(
            job.mc,
            JobTools.task_dir(job, task);
            parameters = task.params,
            data_type = Float64,
        )
    end
end
