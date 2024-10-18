using Carlo
using JSON
using Carlo.ResultTools

@testset "Results" begin
    result_obs = Carlo.ResultObservable(
        Int64(100),
        Int64(3),
        [1.0, 2.0, 3.0],
        [0.1, 0.1, 0.1],
        [0.1, 0.2, 0.3],
        zeros(3, 4),
    )

    repr = JSON.parse(JSON.json(result_obs, 1))
    @test repr["mean"] == result_obs.mean
    @test repr["error"] == result_obs.error
end

@testset "ResultTools" begin
    @testset "recursive_stack" begin
        v = reshape(1:60, 3, 5, 4)
        @test v == ResultTools.recursive_stack(JSON.parse(JSON.json(v)))

        @test ResultTools.recursive_stack(nothing) === nothing
        @test ResultTools.recursive_stack([nothing, nothing]) == [nothing, nothing]
    end
end
