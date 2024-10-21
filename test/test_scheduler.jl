@testset "Task Selection" begin
    @test Carlo.get_new_task_id(Carlo.SchedulerTask[], 0) === nothing
    @test Carlo.get_new_task_id_with_significant_work(Carlo.SchedulerTask[], 0) === nothing

    sweeps = [100, 10, 10, 101, 10]
    tasks = [Carlo.SchedulerTask(100, s, 10, "") for s in sweeps]

    @test Carlo.get_new_task_id(tasks, 1) == 2
    @test Carlo.get_new_task_id(tasks, 2) == 3
    @test Carlo.get_new_task_id(tasks, 3) == 5
    @test Carlo.get_new_task_id(tasks, 4) == 5
    @test Carlo.get_new_task_id(tasks, 5) == 2

    tasks = [Carlo.SchedulerTask(100, s, 10, "") for s in [100, 100, 100]]
    for i = 1:length(tasks)
        @test Carlo.get_new_task_id(tasks, i) === nothing
    end

    @test Carlo.get_new_task_id(tasks, nothing) === nothing
end

@testset "Task Scheduling" begin
    mktempdir() do tmpdir
        @testset "MPI parallel run mode" begin
            mc = TestParallelRunMC
            job_2rank = make_test_job("$tmpdir/test2_2rank", 100; mc, ranks_per_run = 2)

            run_test_job_mpi(job_2rank; num_ranks = 5)
            tasks = JT.read_progress(job_2rank)
            for task in tasks
                @test task.sweeps >= task.target_sweeps
            end

            job_all_full =
                make_test_job("$tmpdir/test2_full", 200; mc, ranks_per_run = :all)
            run_test_job_mpi(job_all_full; num_ranks = 5)

            # test checkpointing by resetting the seed on a finished simulation
            job_all_half =
                make_test_job("$tmpdir/test2_half", 100; mc, ranks_per_run = :all)
            run_test_job_mpi(job_all_half; num_ranks = 5)
            job_all_half =
                make_test_job("$tmpdir/test2_half", 200; mc, ranks_per_run = :all)
            run_test_job_mpi(job_all_half; num_ranks = 5)

            compare_results(job_all_full, job_all_half)

            tasks = JT.read_progress(job_all_half)
            for task in tasks
                @test task.num_runs == 1
                @test task.sweeps == task.target_sweeps
            end

            job_fail = make_test_job(
                "$tmpdir/test2_fail",
                100;
                mc,
                ranks_per_run = 2,
                try_measure_on_nonroot = true,
            )
            @test_throws ProcessFailedException run_test_job_mpi(
                job_fail;
                num_ranks = 5,
                silent = true,
            ) # only run leader can measure
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
                start(Carlo.SingleScheduler, job3_full)

                job3_halfhalf = make_test_job("$tmpdir/test3_halfhalf", 100)
                start(Carlo.SingleScheduler, job3_halfhalf)
                job3_halfhalf = make_test_job("$tmpdir/test3_halfhalf", 200)
                start(Carlo.SingleScheduler, job3_halfhalf)

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
