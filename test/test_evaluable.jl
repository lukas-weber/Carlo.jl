@testset "Evaluable" begin
    @testset "scalar" begin
        func = (x::Real, y::Real) -> x / y
        means = ([2, 3, 4], [5, 4, 3])
        mean, error, cov = Carlo.jackknife(func, means, false)
        @test mean ≈ [0.712962962962963]
        @test error ≈ [0.25726748128610744]
        @test isnothing(cov)

        # With covariance
        mean2, error2, cov2 = Carlo.jackknife(func, means, true)
        @test mean2 ≈ mean
        @test error2 ≈ error
        @test isnothing(cov2)
    end

    @testset "vector" begin
        func = x -> x[1] / x[2]
        means = ([2 3 4; 5 4 3],)
        mean, error, cov = Carlo.jackknife(func, means, false)
        @test mean ≈ [0.712962962962963]
        @test error ≈ [0.25726748128610744]

        func2 = x -> [x[1] / x[2], 2x[1] / x[2]]
        mean2, error2, cov2 = Carlo.jackknife(func2, means, true)
        @test mean2 ≈ [0.712962962962963, 2 * 0.712962962962963]
        @test error2 ≈ [0.25726748128610744, 2 * 0.25726748128610744]
        @test size(cov2) == (2, 2)
        # diagonal should be squared errors
        @test cov2[1, 1] ≈ error2[1]^2
        @test cov2[2, 2] ≈ error2[2]^2
        # note Cov(f1, 2*f1) = 2*Var(f1)
        @test cov2[1, 2] ≈ 2 * error2[1]^2
        @test cov2[2, 1] ≈ 2 * error2[1]^2
    end

    @testset "matrix" begin
        func_vec = (x, y) -> x ./ y
        func_mat = x -> x[:, 1] ./ x[:, 2]
        means_vec = (rand(3, 5), rand(3, 5))
        means_mat = (stack(means_vec, dims = 2),)

        mean_v, error_v, cov_v = Carlo.jackknife(func_vec, means_vec, true)
        mean_m, error_m, cov_m = Carlo.jackknife(func_mat, means_mat, true)

        @test mean_v ≈ mean_m
        @test error_v ≈ error_m
        @test cov_v ≈ cov_m
    end

    @testset "ComplexScalar" begin
        func3 = (x::Complex, y::Complex) -> x / y
        means = ([1 + 0im, 1 + 1im, 1 + 2im], [2 - 0im, 2 - 1im, 2 - 2im])
        mean, error, cov = Carlo.jackknife(func3, means, true)

        @test error[1] isa Real
        @test mean ≈ [0.2188235294117648 + 0.6847058823529415im]
        @test error ≈ [0.3388562075744883]
        # @test real(cov[1]) ≈ error[1]^2
        @test isnothing(cov)
    end

    @testset "covariance properties" begin
        # check tensor structure of covariance (with 2x2 matrix)
        func = x -> [x[1] x[2]; x[3] x[1]+x[2]]
        means = (randn(4, 20),)

        mean, error, cov = Carlo.jackknife(func, means, true)

        @test size(mean) == (2, 2)
        @test size(error) == (2, 2)
        @test size(cov) == (2, 2, 2, 2)

        for i in 1:2, j in 1:2
            @test cov[i, j, i, j] ≈ error[i, j]^2
        end

        # symmetry: Cov(X_ij, X_kl) == Cov(X_kl, X_ij)
        for i in 1:2, j in 1:2, k in 1:2, l in 1:2
            @test cov[i, j, k, l] ≈ cov[k, l, i, j]
        end
    end

    @testset "covariance complex vector" begin
        # Complex vector output
        func = (x, y) -> [x / y, x * y]
        means = ([1.0+1im, 2.0+0.5im, 1.5+1.5im], [2.0-0.5im, 1.5-1im, 2.5-0.5im])

        mean, error, cov = Carlo.jackknife(func, means, true)

        @test size(cov) == (2, 2)
        # diagonal (variances) should be real
        @test imag(cov[1, 1]) ≈ 0 atol=1e-14
        @test imag(cov[2, 2]) ≈ 0 atol=1e-14
        # symmetry: Cov[i,j] == conj(Cov[j,i])
        @test cov[1, 2] ≈ conj(cov[2, 1])
    end

end
