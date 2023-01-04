using Random

import LoadLeveller

@testset "Walker" begin
    params = Dict(:thermalization => 100, :binsize => 13)
    walker = LoadLeveller.Walker{TestMC,Random.Xoshiro}(params)

    sweeps = 131
    for i = 1:sweeps
        LoadLeveller.step!(walker)
    end
    @test walker.context.sweeps == sweeps


    tmpdir = mktempdir()
    LoadLeveller.write_checkpoint!(walker, tmpdir * "/test")
    @test nothing == LoadLeveller.read_checkpoint(
        LoadLeveller.Walker{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )
    LoadLeveller.write_checkpoint_finalize(tmpdir * "/test")


    walker2 = LoadLeveller.read_checkpoint(
        LoadLeveller.Walker{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )

    @test walker.implementation == walker2.implementation
    @test walker.context.rng == walker2.context.rng
    LoadLeveller.step!(walker)
    LoadLeveller.write_checkpoint!(walker, tmpdir * "/test")

    walker3 = LoadLeveller.read_checkpoint(
        LoadLeveller.Walker{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
    )
    @test walker3.implementation == walker2.implementation
    @test walker3.context.rng == walker2.context.rng
end
