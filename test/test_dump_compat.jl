
function compat_job()
    return JobInfo(
        "dump_compat",
        TestMC;
        tasks = [
            TaskInfo("v0.1.5", Dict(:sweeps => 100, :thermalization => 0, :binsize => 10)),
        ],
        checkpoint_time = "00:05",
        run_time = "00:10",
    )
end

@testset "Checkpoint compatibility" begin

    job = compat_job()
    progress = JobTools.read_progress(job)

    MPI.Init()
    for (i, task) in enumerate(job.tasks)
        @testset "$(task.name)" begin
            run = Carlo.read_checkpoint(
                Carlo.Run{job.mc,job.rng},
                "dump_compat.data/$(task.name)/run0001",
                task.params,
                MPI.COMM_WORLD,
            )
            Carlo.step!(run, MPI.COMM_WORLD)

            @test run.context.sweeps - run.context.thermalization_sweeps ==
                  progress[i].sweeps + 1

            results = Carlo.merge_results(
                ["dump_compat.data/$(task.name)/run0001.meas.h5"];
                rebin_length = nothing,
            )
            obs_names = Set([
                :_ll_sweep_time,
                :test,
                :test2,
                :test_rng,
                :_ll_checkpoint_write_time,
                :test_vec,
                :_ll_measure_time,
            ])
            @test obs_names == Set(keys(results))

            df = ResultTools.dataframe("dump_compat.data/$(task.name)/results.json")
            @test issubset(obs_names..., Symbol.(keys(only(df))))
        end
    end
end
