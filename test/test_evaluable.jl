using LoadLeveller

@testset "Evaluable" begin
    func = (x::Real, y::Real) -> x / y

    means = map(transpose, [[2, 3, 4], [5, 4, 3]])

    # TODO: proper statistical test
    @test all(
        LoadLeveller.jackknife(func, means) .≈ ([0.712962962962963], [0.25726748128610744]),
    )
end
