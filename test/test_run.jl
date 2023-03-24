using Random

import LoadLeveller

@testset "Run" begin
    params = Dict(:thermalization => 100, :binsize => 13)
    run = LoadLeveller.Run{TestMC,Random.Xoshiro}(params)

    sweeps = 131
    for i = 1:sweeps
        LoadLeveller.step!(run)
    end
    @test run.context.sweeps == sweeps


    tmpdir = mktempdir()
    LoadLeveller.write_checkpoint!(run, tmpdir * "/test")
    @test nothing == LoadLeveller.read_checkpoint(
        LoadLeveller.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )
    LoadLeveller.write_checkpoint_finalize(tmpdir * "/test")


    run2 = LoadLeveller.read_checkpoint(
        LoadLeveller.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )

    @test run.implementation == run2.implementation
    @test run.context.rng == run2.context.rng
    LoadLeveller.step!(run)
    LoadLeveller.write_checkpoint!(run, tmpdir * "/test")

    run3 = LoadLeveller.read_checkpoint(
        LoadLeveller.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )
    @test run3.implementation == run2.implementation
    @test run3.context.rng == run2.context.rng
end
