include("compat_job.jl")

@testset "Checkpoint compatibility" begin
    mktempdir() do tmpdir
        cp("dump_compat.data", tmpdir * "/dump_compat.data")

        versions = map(filter(!endswith("json"), readdir("dump_compat.data"))) do task
            m = match(r"julia(?<juliaver>[\d\.]+)-(?<carlover>[\d\.]+$)", task)
            return VersionNumber.((m["juliaver"], m["carlover"]))
        end

        job = compat_job(versions; dir = tmpdir)
        progress = JobTools.read_progress(job)

        obs_names = Set([
            :_ll_sweep_time,
            :test,
            :test2,
            :test4,
            :test_rng,
            :test_vec,
            :_ll_measure_time,
        ])

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
                for i = 1:100
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
                      progress[i].sweeps + 100


                Carlo.merge_results(
                    job.mc,
                    "$tmpdir/dump_compat.data/$(task.name)";
                    parameters = task.params,
                )
            end
        end
        JobTools.concatenate_results(job)
        df = ResultTools.dataframe("$tmpdir/dump_compat.results.json")

        dfs = reduce(
            vcat,
            [
                ResultTools.dataframe(
                    "dump_compat.data/julia$juliaver-$carlover.results.json",
                ) for (juliaver, carlover) in versions
            ],
        )

        for (tasknew, taskold) in zip(df, dfs)
            for obs_name in string.(obs_names)
                @test tasknew[obs_name] ≈ taskold[obs_name]
            end
        end


    end
end
