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

@testset "Task Scheduling" begin
    tm = JT.TaskMaker()
    tm.sweeps = 100
    tm.thermalization = 14
    tm.binsize = 4

    for i = 1:3
        task(tm; i = i)
    end

    tmpdir = mktempdir()

    @testset "MPI" begin
        job = LoadLeveller.JobInfo(
            tmpdir * "/test";
            tasks = make_tasks(tm),
            checkpoint_time = "1:00",
            run_time = "10:00",
        )

        JT.create_job_directory(job)

        num_ranks = 3
        mpiexec() do exe
            run(`$exe -n $num_ranks $(Base.julia_cmd()) test_runner_mpi.jl $(job.dir)`)
        end
        tasks = JT.read_progress(job)
        for task in tasks
            @test task[:sweeps] >= task[:target_sweeps]
        end
    end
    @testset "Single" begin
        job2 = LoadLeveller.JobInfo(
            tmpdir * "/test2";
            tasks = JT.make_tasks(tm),
            checkpoint_time = "1:00",
            run_time = "10:00",
        )

        JT.create_job_directory(job2)

        LoadLeveller.start(LoadLeveller.SingleRunner{TestMC}, job2)

        tasks = JT.read_progress(job2)
        for task in tasks
            @test task[:sweeps] >= task[:target_sweeps]
        end
    end
end
