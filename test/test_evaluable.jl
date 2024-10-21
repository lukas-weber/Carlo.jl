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

    @testset "matrix" begin
        func_vec = (x, y) -> x ./ y
        func_mat = x -> x[:, 1] ./ x[:, 2]

        means_vec = (rand(3, 5), rand(3, 5))
        means_mat = (stack(means_vec, dims = 2),)

        @test all(
            Carlo.jackknife(func_mat, means_mat) .≈ Carlo.jackknife(func_vec, means_vec),
        )
    end

    @testset "ComplexScalar" begin
        func3 = (x::Complex, y::Complex) -> x / y

        means = ([1 + 0im, 1 + 1im, 1 + 2im], [2 - 0im, 2 - 1im, 2 - 2im])
        results = Carlo.jackknife(func3, means)
        @test results[2][1] isa Real
        @test all(
            results .≈ ([0.2188235294117648 + 0.6847058823529415im], [0.3388562075744883]),
        )
    end

end
