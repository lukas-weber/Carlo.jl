using LoadLeveller
using JSON


@testset "Results" begin
    merged_obs = LoadLeveller.MergedObservable{Float64}(100, 3)
    merged_obs.mean = [1, 2, 3]
    merged_obs.error = [0.1, 0.1, 0.1]

    result_obs = LoadLeveller.ResultObservable(merged_obs)

    @test result_obs.mean == merged_obs.mean
    @test result_obs.error == merged_obs.error

    repr = JSON.parse(JSON.json(result_obs, 1))
    @test repr["mean"] == merged_obs.mean
    @test repr["error"] == merged_obs.error
end
