function test_binning_properties(result_file)
    results = JSON.parsefile(result_file)

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
    tmpdir = mktempdir()
    dummy_jobfile = "dummy_jobfile.jl"

    run_cmd(cmd; quiet = false) = run(
        pipeline(
            `$(Base.julia_cmd()) $dummy_jobfile $tmpdir $cmd`,
            stderr = quiet ? devnull : stderr,
        ),
    )

    @test_throws ProcessFailedException run_cmd("status"; quiet = true)
    @test_throws ProcessFailedException run_cmd("merge"; quiet = true)
    run_cmd("delete")
    @test !isfile(tmpdir * "/test.results.json")

    run_cmd(`run`)

    run_cmd("status")
    run_cmd("merge")
    @test isfile(tmpdir * "/test.results.json")

    test_binning_properties(tmpdir * "/test.results.json")
    run_cmd("delete")
    @test !isfile(tmpdir * "/test.results.json")
    @test !isdir(tmpdir * "/test")

    tm = TaskMaker()
    tm.sweeps = 100
    tm.thermalization = 100
    tm.binsize = 10
    task(tm)

    job = JobInfo(
        tmpdir * "/test",
        TestMC;
        tasks = make_tasks(tm),
        checkpoint_time = "00:05",
        run_time = "00:10",
    )

    JobTools.create_job_directory(job)
    run_cmd("status")
end
