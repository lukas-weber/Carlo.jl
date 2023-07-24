using Serialization
using LoadLeveller.ResultTools
using Logging

@testset "Task Selection" begin
    sweeps = [100, 10, 10, 101, 10]
    tasks = map(s -> LoadLeveller.RunnerTask(100, s, "", 0), sweeps)

    @test LoadLeveller.get_new_task_id(tasks, 1) == 2
    @test LoadLeveller.get_new_task_id(tasks, 2) == 3
    @test LoadLeveller.get_new_task_id(tasks, 3) == 5
    @test LoadLeveller.get_new_task_id(tasks, 4) == 5
    @test LoadLeveller.get_new_task_id(tasks, 5) == 2

    tasks = map(s -> LoadLeveller.RunnerTask(100, s, "", 0), [100, 100, 100])
    for i = 1:length(tasks)
        @test LoadLeveller.get_new_task_id(tasks, i) === nothing
    end

    @test LoadLeveller.get_new_task_id(tasks, nothing) === nothing
end

function make_test_job(dir::AbstractString, sweeps::Integer; ranks_per_run = 1, kwargs...)
    tm = TaskMaker()
    tm.sweeps = sweeps
    tm.seed = 13245432
    tm.thermalization = 14
    tm.binsize = 1
    for (k, v) in kwargs
        setproperty!(tm, k, v)
    end

    for i = 1:3
        task(tm; i = i)
    end

    return JobInfo(
        dir,
        ranks_per_run == 1 ? TestMC : TestParallelRunMC;
        tasks = make_tasks(tm),
        checkpoint_time = "1:00",
        run_time = "10:00",
        ranks_per_run = ranks_per_run,
    )
end

function run_test_job_mpi(job::JobInfo; num_ranks::Integer, silent::Bool = false)
    JT.create_job_directory(job)
    job_path = job.dir * "/jobfile"
    serialize(job_path, job)

    mpiexec() do exe
        cmd = `$exe -n $num_ranks $(Base.julia_cmd()) test_runner_mpi.jl $(job_path)`
        if silent
            cmd = pipeline(cmd; stdout = devnull, stderr = devnull)
        end
        run(cmd)
    end

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

@testset "Task Scheduling" begin
    mktempdir() do tmpdir
        @testset "MPI parallel run mode" begin
            job_2rank = make_test_job("$tmpdir/test2_2rank", 100, ranks_per_run = 2)

            run_test_job_mpi(job_2rank; num_ranks = 4)
            tasks = JT.read_progress(job_2rank)
            for task in tasks
                @test task.sweeps >= task.target_sweeps
            end

            job_all_full = make_test_job("$tmpdir/test2_full", 200, ranks_per_run = :all)
            run_test_job_mpi(job_all_full; num_ranks = 4)

            # test checkpointing by resetting the seed on a finished simulation
            job_all_half = make_test_job("$tmpdir/test2_half", 100, ranks_per_run = :all)
            run_test_job_mpi(job_all_half; num_ranks = 4)
            job_all_half = make_test_job("$tmpdir/test2_half", 200, ranks_per_run = :all)
            run_test_job_mpi(job_all_half; num_ranks = 4)

            compare_results(job_all_full, job_all_half)

            tasks = JT.read_progress(job_all_half)
            for task in tasks
                @test task.num_runs == 1
                @test task.sweeps == task.target_sweeps
            end

            job_fail = make_test_job(
                "$tmpdir/test2_fail",
                100;
                ranks_per_run = 2,
                try_measure_on_nonroot = true,
            )
            @test_throws ProcessFailedException run_test_job_mpi(
                job_fail;
                num_ranks = 4,
                silent = true,
            ) # only run leader can measure
            @test_throws ProcessFailedException run_test_job_mpi(
                job_2rank;
                num_ranks = 3,
                silent = true,
            ) # number of ranks needs to be commensurate
        end

        @testset "MPI" begin
            job = make_test_job("$tmpdir/test1", 100)
            run_test_job_mpi(job; num_ranks = 4)

            tasks = JT.read_progress(job)
            for task in tasks
                @test task.sweeps >= task.target_sweeps
            end
        end

        @testset "Single" begin
            with_logger(Logging.NullLogger()) do
                job3_full = make_test_job("$tmpdir/test3_full", 200)
                start(LoadLeveller.SingleRunner, job3_full)

                job3_halfhalf = make_test_job("$tmpdir/test3_halfhalf", 100)
                start(LoadLeveller.SingleRunner, job3_halfhalf)
                job3_halfhalf = make_test_job("$tmpdir/test3_halfhalf", 200)
                start(LoadLeveller.SingleRunner, job3_halfhalf)

                for job in (job3_full, job3_halfhalf)
                    tasks = JT.read_progress(job)
                    for task in tasks
                        @test task.sweeps == task.target_sweeps
                    end
                end
                compare_results(job3_full, job3_halfhalf)
            end
        end
    end
end
