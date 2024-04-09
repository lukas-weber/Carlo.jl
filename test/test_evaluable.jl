using Carlo

@testset "Evaluable" begin
    @testset "scalar" begin
        func = (x::Real, y::Real) -> x / y

        means = ([2, 3, 4], [5, 4, 3])

        # TODO: proper statistical test
        @test all(
            Carlo.jackknife(func, means) .≈ ([0.712962962962963], [0.25726748128610744]),
        )
    end

    @testset "vector" begin
        func = x -> x[1] / x[2]

        means = ([2 3 4; 5 4 3],)

        @test all(
            Carlo.jackknife(func, means) .≈ ([0.712962962962963], [0.25726748128610744]),
        )

        func2 = x -> [x[1] / x[2], 2x[1] / x[2]]

        @test all(
            Carlo.jackknife(func2, means) .≈ (
                [0.712962962962963, 2 * 0.712962962962963],
                [0.25726748128610744, 2 * 0.25726748128610744],
            ),
        )
    end

end
