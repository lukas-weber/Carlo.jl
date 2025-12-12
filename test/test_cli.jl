function test_binning_properties(result_file)
    results = JSON.parsefile(result_file; allownan = true)

    for result in results
        sweeps = result["parameters"]["sweeps"]
        bin_length = result["parameters"]["binsize"]
        rebin_length = result["parameters"]["rebin_length"]
        rebin_sample_skip = result["parameters"]["rebin_sample_skip"]

        for (obsname, obs) in result["results"]
            if startswith(obsname, "_ll_") || isnothing(obs["internal_bin_len"])
                continue
            end

            @test rebin_length == obs["rebin_len"]
            @test bin_length == obs["internal_bin_len"]
            @test obs["rebin_count"] * rebin_length <
                  sweeps ÷ bin_length - rebin_sample_skip
        end
    end
end

@testset "CLI" begin
    mktempdir() do tmpdir
        dummy_jobfile = joinpath(tmpdir, "dummy_jobfile.jl")
        test_mc_path = abspath("test_mc.jl")
        write(
            dummy_jobfile,
            """
    using Carlo
    using Carlo.JobTools
    include("$test_mc_path")

    tm = TaskMaker()
    tm.binsize = 2

    tm.rebin_sample_skip = 1000
    tm.rebin_length = 1000

    tm.sweeps = 10
    tm.thermalization = 0
    task(tm)
    tm.thermalization = 100000
    tm.sweeps = 100000000000
    task(tm)
    task(tm)

    job = JobInfo(
        "$tmpdir/test",
        TestMC;
        tasks = make_tasks(tm),
        checkpoint_time = "00:05",
        run_time = "00:10",
    )

    Carlo.start(job, ARGS)
""",
        )

        run_cmd(cmd; quiet = false) = read(
            pipeline(
                `$(Base.julia_cmd()) $dummy_jobfile $cmd`,
                stderr = quiet ? devnull : stderr,
            ),
        )

        @test_throws ProcessFailedException run_cmd("status"; quiet = true)
        @test_throws ProcessFailedException run_cmd("merge"; quiet = true)
        run_cmd("delete")
        @test !isfile(tmpdir * "/test.results.json")

        run_cmd("run")

        run_cmd("status")
        run_cmd("merge")
        @test isfile(tmpdir * "/test.results.json")

        test_binning_properties(tmpdir * "/test.results.json")
        run_cmd("delete")
        @test !isfile(tmpdir * "/test.results.json")
        @test !isdir(tmpdir * "/test")

        write(
            dummy_jobfile,
            """
    using Carlo
    using Carlo.JobTools
    include("$test_mc_path")

    tm = TaskMaker()
    tm.sweeps = 1
    tm.thermalization = 1
    tm.binsize = 10
    for _ = 1:100
        task(tm)
    end
    job = JobInfo(
        "$tmpdir/test",
        TestMC;
        tasks = make_tasks(tm),
        checkpoint_time = "00:05",
        run_time = "00:10",
    )

    Carlo.start(job, ARGS)
""",
        )

        run_cmd(`run -s`)
        text = String(run_cmd("status"))

        for i = 1:100
            @test occursin(string(i), text)
        end
        write(
            dummy_jobfile,
            """
    using Carlo
    using Carlo.JobTools
    include("$test_mc_path")

    tm = TaskMaker()
    job = JobInfo(
        "$tmpdir/test",
        TestMC;
        tasks = make_tasks(tm),
        checkpoint_time = "00:05",
        run_time = "00:10",
    )

    Carlo.start(job, ARGS)
""",
        )
        run_cmd("status")
    end
end
