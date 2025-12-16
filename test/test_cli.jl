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

@testset "TinyArgParse" begin
    AP = Carlo.TinyArgParse
    commands = [
        AP.Command(
            "run",
            "r",
            "Run fast",
            [
                AP.Option("single", "s", "Run in single core mode"),
                AP.Option("restart", "r", "Delete existing files and start from scratch"),
                AP.help(),
            ],
        ),
        AP.Command("walk", "w", "Walk around", [AP.help()]),
    ]

    general_args = [AP.Option("test", "t", "Test"), AP.help()]

    @test_throws AP.Error AP.parse(commands, general_args, ["-a"])
    @test_throws AP.Error AP.parse(commands, general_args, ["run", "-a"])
    @test_throws AP.Error AP.parse(commands, general_args, ["r", "-a"])
    @test_throws AP.Error AP.parse(commands, general_args, ["r", "--all"])
    @test_throws AP.Error AP.parse(commands, general_args, ["r", "-h", "r"])
    @test_throws AP.Error AP.parse(commands, general_args, ["runa"])

    cmd, general, specific = AP.parse(commands, general_args, ["r", "-r", "-s"])
    @test cmd == "run"
    @test specific["single"]
    @test specific["restart"]
    @test length(keys(specific)) == 2
    cmd, general, specific = AP.parse(commands, general_args, ["r", "--help", "-r", "-s"])
    @test cmd == "run"
    @test specific["single"]
    @test specific["restart"]
    @test specific["help"]
    @test length(keys(specific)) == 3
    cmd, general, specific = AP.parse(commands, general_args, ["run", "-rs"])
    @test cmd == "run"
    @test specific["single"]
    @test specific["restart"]
    @test length(keys(specific)) == 2
    cmd, general, specific = AP.parse(commands, general_args, ["--test", "run", "-h"])
    @test only(pairs(general)) == ("test" => true)
    @test length(keys(general)) == 1
    @test cmd == "run"
    @test only(pairs(specific)) == ("help" => true)
end

function capture_output(func)
    original_stdout = stdout
    original_stderr = stderr
    (readout, writeout) = redirect_stdout()
    (readerr, writeerr) = redirect_stderr()

    try
        func()
    finally
        redirect_stdout(original_stdout)
        redirect_stderr(original_stderr)
        close(writeout)
        close(writeerr)
    end

    return read(readout, String), read(readerr, String)
end


@testset "CLI" begin
    mktempdir() do tmpdir

        tm = TaskMaker()
        tm.binsize = 200

        tm.rebin_sample_skip = 1000
        tm.rebin_length = 1000

        tm.sweeps = 10
        tm.thermalization = 0
        task(tm)
        tm.thermalization = 100
        tm.sweeps = 100000000000
        task(tm)
        task(tm)

        job = JobInfo(
            "$tmpdir/test",
            TestMC;
            tasks = make_tasks(tm),
            checkpoint_time = "00:10",
            run_time = "00:00",
        )

        @test contains(capture_output() do
            start(job, ["status"])
        end[2], "Error")
        @test contains(capture_output() do
            start(job, ["merge"])
        end[2], "Error")
        start(job, ["delete"])


        @test contains(capture_output(() -> start(job, ["a"]))[2], "Error")
        @test contains(capture_output(() -> start(job, ["--help"]))[1], "Usage")
        @test contains(capture_output(() -> start(job, ["r", "--help"]))[1], "Usage")
        @test contains(capture_output(() -> start(job, ["s", "--help"]))[1], "Usage")
        @test contains(capture_output(() -> start(job, ["m", "--help"]))[1], "Usage")

        @test !isfile(tmpdir * "/test.results.json")

        start(job, ["r"])
        start(job, ["s"])
        start(job, ["m"])
        @test isfile(tmpdir * "/test.results.json")

        test_binning_properties(tmpdir * "/test.results.json")
        start(job, ["d"])
        @test !isfile(tmpdir * "/test.results.json")
        @test !isdir(tmpdir * "/test")

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
            checkpoint_time = "00:10",
            run_time = "00:00",
        )

        start(job, ["run", "-s"])
        io = IOBuffer()

        text = capture_output() do
            start(job, ["status"])
        end[1]

        for i = 1:100
            @test occursin(string(i), text)
        end
        job = JobInfo(
            "$tmpdir/test",
            TestMC;
            tasks = TaskInfo[],
            checkpoint_time = "00:05",
            run_time = "00:10",
        )

        Carlo.start(job, ["status"])
    end
end
