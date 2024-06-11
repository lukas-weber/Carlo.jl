using Carlo
using JSON


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
