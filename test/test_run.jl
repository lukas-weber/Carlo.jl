using Random

import Carlo

@testset "Run" begin
    params = Dict(:thermalization => 100, :binsize => 13)
    run = Carlo.Run{TestMC,Random.Xoshiro}(params)

    sweeps = 131
    for i = 1:sweeps
        Carlo.step!(run)
    end
    @test run.context.sweeps == sweeps


    tmpdir = mktempdir()
    Carlo.write_checkpoint!(run, tmpdir * "/test")
    @test nothing ==
          Carlo.read_checkpoint(Carlo.Run{TestMC,Random.Xoshiro}, tmpdir * "/test", params)
    Carlo.write_checkpoint_finalize(tmpdir * "/test")


    run2 = Carlo.read_checkpoint(Carlo.Run{TestMC,Random.Xoshiro}, tmpdir * "/test", params)

    @test run.implementation == run2.implementation
    @test run.context.rng == run2.context.rng
    Carlo.step!(run)
    Carlo.write_checkpoint!(run, tmpdir * "/test")

    run3 = Carlo.read_checkpoint(Carlo.Run{TestMC,Random.Xoshiro}, tmpdir * "/test", params)
    @test run3.implementation == run2.implementation
    @test run3.context.rng == run2.context.rng
end
