include("compat_job.jl")

@testset "Checkpoint compatibility" begin

    job = compat_job([(v"1.10.2", v"0.1.5")])
    progress = JobTools.read_progress(job)

    obs_names =
        Set([:_ll_sweep_time, :test, :test2, :test_rng, :test_vec, :_ll_measure_time])

    MPI.Init()
    for (i, task) in enumerate(job.tasks)
        @testset "$(task.name)" begin
            if VERSION < task.params[:min_julia_version]
                continue
            end
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
            @test obs_names == Set(keys(results))

        end
    end
    df = ResultTools.dataframe("dump_compat.results.json")
    @test issubset(obs_names, Symbol.(keys(only(df))))
end
