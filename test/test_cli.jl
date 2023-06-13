@testset "CLI" begin
    tmpdir = mktempdir()
    dummy_jobfile = "dummy_jobfile.jl"

    run_cmd(cmd) =
        run(pipeline(`$(Base.julia_cmd()) $dummy_jobfile $tmpdir $cmd`, stderr = devnull))

    @test_throws ProcessFailedException run_cmd("status")
    @test_throws ProcessFailedException run_cmd("merge")
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
