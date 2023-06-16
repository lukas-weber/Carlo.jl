using LoadLeveller

@testset "Evaluable" begin
    @testset "scalar" begin
        func = (x, y) -> x / y

        means = ([2 3 4], [5 4 3])

        # TODO: proper statistical test
        @test all(
            LoadLeveller.jackknife(func, means) .≈
            ([0.712962962962963], [0.25726748128610744]),
        )
    end

    @testset "vector" begin
        func = x -> x[1] / x[2]

        means = ([[2, 5], [3, 4], [4, 3]],)

        @test all(
            LoadLeveller.jackknife(func, means) .≈
            ([0.712962962962963], [0.25726748128610744]),
        )

        func2 = x -> [x[1] / x[2], 2x[1] / x[2]]

        @test all(
            LoadLeveller.jackknife(func2, means) .≈ (
                [0.712962962962963, 2 * 0.712962962962963],
                [0.25726748128610744, 2 * 0.25726748128610744],
            ),
        )
    end

end
