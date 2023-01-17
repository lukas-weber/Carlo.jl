using ArgParse

function start(job::JobInfo, args::AbstractVector{String})
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
        cli_delete(job, Dict())
    end

    JobTools.create_job_directory(job)
    runner = args["single"] ? SingleRunner : MPIRunner
    return start(job, runner{job.mc})
end

function cli_status(job::JobInfo, ::AbstractDict)
    tasks = JobTools.read_progress(job)

    println(tasks)

    return all(map(x -> x[:sweeps] >= x[:target_sweeps], tasks))
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
            task_dir(job, task);
            parameters = task.params,
            datatype = Float64,
        )
    end
end
