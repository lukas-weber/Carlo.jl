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

    run_cmd(`run --single`)

    run_cmd("status")
    run_cmd("merge")
    @test isfile(tmpdir * "/test.results.json")
    run_cmd("delete")
    @test !isfile(tmpdir * "/test.results.json")
    @test !isdir(tmpdir * "/test")
end
