function tmp_hdf5_file(func::Function)
    tmp = tempname(cleanup = true)
    res = try
        h5open(func, tmp, "w")
    finally
        rm(tmp)
    end
    return res
end


function test_checkpointing(obj; type = typeof(obj))
    return tmp_hdf5_file() do file
        group = create_group(file, "test")
        Carlo.write_checkpoint(obj, group)
        obj2 = Carlo.read_checkpoint(type, group)

        return obj == obj2
    end
end

function make_test_job(
    dir::AbstractString,
    sweeps::Integer;
    mc = TestMC,
    ranks_per_run = 1,
    ntasks = 3,
    checkpoint_time = "5:00",
    run_time = "15:00",
    kwargs...,
)
    tm = TaskMaker()
    tm.sweeps = sweeps
    tm.seed = 13245432
    tm.thermalization = 14
    tm.binsize = 1
    for (k, v) in kwargs
        setproperty!(tm, k, v)
    end

    for i = 1:ntasks
        task(tm; i = i)
    end

    return JobInfo(
        dir,
        mc;
        tasks = make_tasks(tm),
        checkpoint_time,
        run_time,
        ranks_per_run = ranks_per_run,
    )
end

function run_test_job_mpi(job::JobInfo; num_ranks::Integer, silent::Bool = false)
    JT.create_job_directory(job)
    job_path = job.dir * "/jobfile"
    serialize(job_path, job)

    cmd = `$(mpiexec()) -n $num_ranks $(Base.julia_cmd()) test_scheduler_mpi.jl $(job_path)`
    if silent
        cmd = pipeline(cmd; stdout = devnull, stderr = devnull)
    end
    run(cmd)

    return nothing
end

function compare_results(job1::JobInfo, job2::JobInfo)
    results1 = ResultTools.dataframe(JT.result_filename(job1))
    results2 = ResultTools.dataframe(JT.result_filename(job2))

    for (task1, task2) in zip(results1, results2)
        for key in keys(task1)
            if !startswith(key, "_ll_")
                @test (key, task1[key]) == (key, task2[key])
            end
        end
    end
end
