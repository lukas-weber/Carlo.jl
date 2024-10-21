@testset "Run" begin
    params = Dict(:thermalization => 100, :binsize => 13)
    MPI.Init()
    run = Carlo.Run{TestMC,Random.Xoshiro}(params, MPI.COMM_WORLD)

    sweeps = 131
    for i = 1:sweeps
        Carlo.step!(run, MPI.COMM_WORLD)
    end
    @test run.context.sweeps == sweeps


    tmpdir = mktempdir()
    Carlo.write_checkpoint!(run, tmpdir * "/test", MPI.COMM_WORLD)
    @test nothing === Carlo.read_checkpoint(
        Carlo.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
        MPI.COMM_WORLD,
    )
    Carlo.write_checkpoint_finalize(tmpdir * "/test")

    run2 = Carlo.read_checkpoint(
        Carlo.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
        MPI.COMM_WORLD,
    )

    @test run.implementation == run2.implementation
    @test run.context.rng == run2.context.rng
    Carlo.step!(run, MPI.COMM_WORLD)
    Carlo.write_checkpoint!(run, tmpdir * "/test", MPI.COMM_WORLD)

    run3 = Carlo.read_checkpoint(
        Carlo.Run{TestMC,Random.Xoshiro},
        tmpdir * "/test",
        params,
        MPI.COMM_WORLD,
    )
    @test run3.implementation == run2.implementation
    @test run3.context.rng == run2.context.rng
end
