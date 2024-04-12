include("compat_job.jl")

@testset "Checkpoint compatibility" begin

    mktempdir() do tmpdir
        cp("dump_compat.data", tmpdir * "/dump_compat.data")
        cp("dump_compat.results.json", tmpdir * "/dump_compat.results.json")
        @show readdir(tmpdir)

        job = compat_job([(v"1.10.2", v"0.1.5")]; dir = tmpdir)
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
                    "$tmpdir/dump_compat.data/$(task.name)/run0001",
                    task.params,
                    MPI.COMM_WORLD,
                )
                for i = 1:10
                    Carlo.step!(run, MPI.COMM_WORLD)
                end
                Carlo.write_measurements(
                    run,
                    "$tmpdir/dump_compat.data/$(task.name)/run0001",
                )
                Carlo.write_checkpoint!(
                    run,
                    "$tmpdir/dump_compat.data/$(task.name)/run0001",
                    MPI.COMM_WORLD,
                )

                @test run.context.sweeps - run.context.thermalization_sweeps ==
                      progress[i].sweeps + 10

                results = Carlo.merge_results(
                    ["$tmpdir/dump_compat.data/$(task.name)/run0001.meas.h5"];
                    rebin_length = nothing,
                )
                @test obs_names == Set(keys(results))

            end
        end
        df = ResultTools.dataframe("$tmpdir/dump_compat.results.json")
        @test issubset(obs_names, Symbol.(keys(only(df))))
    end
end
