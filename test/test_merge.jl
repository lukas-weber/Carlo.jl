function create_mock_data(
    generator;
    runs::Integer,
    internal_binsize::Integer,
    samples_per_run::Integer,
    extra_samples::Integer = 0,
    obsname::Symbol,
)
    tmpdir = mktempdir()
    all_samples = []

    filenames = ["$tmpdir/run$i.h5" for i = 1:runs]

    idx = 1
    for run = 1:runs
        nsamples = samples_per_run + extra_samples * (run == 1)
        samples = []
        h5open(filenames[run], "w") do file
            meas = Carlo.Measurements(internal_binsize)
            for i = 1:nsamples
                value = generator(idx)
                Carlo.add_sample!(meas, obsname, value)
                if i <= (nsamples ÷ internal_binsize) * internal_binsize
                    append!(samples, value)
                end
                idx += 1
            end
            Carlo.write_measurements!(meas, create_group(file, "observables"))
        end
        push!(all_samples, samples)
    end

    return collect(filenames), all_samples
end

@testset "rebin_count" begin
    for sample_count = 0:100
        rebins = Carlo.calc_rebin_count(sample_count)
        @test (sample_count != 0) <= rebins <= sample_count
    end
end

@testset "Merge counter" begin
    tmpdir = mktempdir()
    runs = 4

    for internal_binsize in [1, 3, 4]
        for samples_per_run in [5, 7]
            extra_samples = 100
            total_samples = runs * samples_per_run + extra_samples

            @testset "samples = $(total_samples), binsize = $(internal_binsize)" begin
                filenames, samples = create_mock_data(;
                    runs = runs,
                    obsname = :count_test,
                    internal_binsize = internal_binsize,
                    samples_per_run = samples_per_run,
                    extra_samples = extra_samples,
                ) do idx
                    return idx
                end

                filenames2, _ = create_mock_data(
                    idx -> [idx+1.0im 1.0; 1.0im 0];
                    runs = runs,
                    obsname = :vec_test,
                    internal_binsize = internal_binsize,
                    samples_per_run = samples_per_run,
                    extra_samples = extra_samples,
                )

                @testset for sample_skip in [0, 10]
                    @testset for rebin_length in [nothing, 1, 2]
                        results = Carlo.merge_results(filenames; rebin_length, sample_skip)
                        count_obs = results[:count_test]

                        skipped_samples = mapreduce(
                            s -> s[1+internal_binsize*sample_skip:end],
                            vcat,
                            samples,
                        )
                        rebinned_samples =
                            skipped_samples[1:internal_binsize*count_obs.rebin_length*Carlo.rebin_count(
                                count_obs,
                            )]

                        @test count_obs.mean[1] ≈ mean(rebinned_samples)
                        if rebin_length !== nothing
                            @test count_obs.rebin_length == rebin_length
                        end

                        results2 = Carlo.merge_results(
                            filenames2;
                            rebin_length = rebin_length,
                            sample_skip,
                        )
                        vec_obs = results2[:vec_test]
                        @test iszero(vec_obs.error[2])
                        @test vec_obs.error[1] ≈ count_obs.error[1]
                        @test vec_obs.mean ≈ [count_obs.mean[1]+1.0im 1.0; 1.0im 0]
                    end
                end
            end
        end
    end
end

@testset "Merge AR(1)" begin
    runs = 2

    # parameters for an AR(1) random walk y_{t+1} = α y_{t} + N(μ=0, σ)
    # autocorrelation time and error of this are known analytically
    for ar1_alpha in [0.5, 0.7, 0.8, 0.9]
        @testset "α = $ar1_alpha" begin
            ar1_sigma = 0.54

            ar1_y = 0
            rng = Xoshiro(520)

            filenames, _ = create_mock_data(;
                runs = runs,
                obsname = :ar1_test,
                samples_per_run = 200000,
                internal_binsize = 1,
            ) do idx
                ar1_y = ar1_alpha * ar1_y + ar1_sigma * randn(rng)
                return ar1_y
            end

            results = Carlo.merge_results(filenames; rebin_length = 100)

            # AR(1)
            ar1_obs = results[:ar1_test]

            expected_mean = 0.0
            expected_std = ar1_sigma / sqrt(1 - ar1_alpha^2)
            # note we changed the definition to 
            # τ_int = ∑_d=1^∞ ρ(d) = ∑_d=1^∞ α^d = α/(1-α)
            expected_autocorrtime = (ar1_alpha) / (1 - ar1_alpha)

            @test abs(ar1_obs.mean[1] - expected_mean) < 4 * ar1_obs.error[1]
            @test isapprox(
                ar1_obs.autocorrelation_time[1],
                expected_autocorrtime,
                rtol = 0.1,
            )
        end
    end
end
@testset "Rotated AR(1)" begin
    # Two independent AR(1) processes
    α1 = 0.5
    α2 = 0.9
    σ1_stat = 1 / (1 - α1^2)
    σ2_stat = 1 / (1 - α2^2)

    # Rotate by 45 degrees
    θ = π / 4
    R = [cos(θ) -sin(θ); sin(θ) cos(θ)]

    # After rotation: y = R*z
    # y1 = (z1 + z2)/√2
    # y2 = (-z1 + z2)/√2
    # lag-d
    # Cov(y1(t), y1(t+d)) = Cov((z1+z2)/√2, (z1+z2)/√2) at lag d
    #                     = (1/2)[Cov(z1(t),z1(t+d)) + Cov(z2(t),z2(t+d))]
    #                     = (1/2)[σ1²*α1^d + σ2²*α2^d]
    # "naive" integrated autocorrelation time would use:
    # τ_naive = Σ_d (Cov(d)/Cov(0)) 
    #         = Σ_d [(σ1²*α1^d + σ2²*α2^d) / (σ1² + σ2²)]
    #         = [σ1²*α1/(1-α1) + σ2²*α2/(1-α2)] / (σ1² + σ2²)

    tau1_original = α1 / (1 - α1)
    tau2_original = α2 / (1 - α2)

    # naive autocorrelation time for y1 (as calculated above)
    tau_y1_analytical =
        (σ1_stat * α1 / (1 - α1) + σ2_stat * α2 / (1 - α2)) / (σ1_stat + σ2_stat)
    tau_y2_analytical = tau_y1_analytical  # By symmetry

    runs = 2
    samples_per_run = 500000

    rng = Xoshiro(599)
    z1 = randn(rng) * sqrt(σ1_stat)
    z2 = randn(rng) * sqrt(σ2_stat)

    filenames, _ = create_mock_data(;
        runs = runs,
        obsname = :rotated_ar1_analytical,
        samples_per_run = samples_per_run,
        internal_binsize = 1,
    ) do idx
        z1 = α1 * z1 + randn(rng)
        z2 = α2 * z2 + randn(rng)
        z = [z1, z2]
        y = R * z
        return y
    end

    results_naive = Carlo.merge_results(filenames; rebin_length = 100, sample_skip = 2000)
    naive_obs = results_naive[:rotated_ar1_analytical]

    results_decorr = Carlo.merge_results(
        filenames;
        rebin_length = 100,
        sample_skip = 2000,
        estimate_covariance = true,
    )
    decorr_obs = results_decorr[:rotated_ar1_analytical]
    decorr_sorted = sort(decorr_obs.autocorrelation_time[:])

    # naive matches analytical prediction
    @test isapprox(naive_obs.autocorrelation_time[1], tau_y1_analytical, rtol = 0.1)
    @test isapprox(naive_obs.autocorrelation_time[2], tau_y2_analytical, rtol = 0.1)

    # decorr recovers original values
    @test isapprox(decorr_sorted[1], tau1_original, rtol = 0.2)
    @test isapprox(decorr_sorted[2], tau2_original, rtol = 0.2)
end

@testset "Multidim AR(1) with one slow mode" begin
    runs = 2
    samples_per_run = 500000
    n_fast = 5

    α_slow = 0.95  # slow mode
    α_fast = 0.3   # fast modes

    τ_slow = α_slow / (1 - α_slow)
    τ_fast = α_fast / (1 - α_fast)

    rng = Xoshiro(678)

    slow = 0.0
    fast = zeros(n_fast)
    # create random (orthogonal) mixing matrix 
    Q, _ = qr(randn(rng, n_fast + 1, n_fast + 1))
    rotation_matrix = Matrix(Q)
    filenames, _ = create_mock_data(;
        runs = runs,
        obsname = :high_dim,
        samples_per_run = samples_per_run,
        internal_binsize = 1,
    ) do idx
        # Update slow mode
        slow = α_slow * slow + randn(rng)
        # Update fast modes
        for i = 1:n_fast
            fast[i] = α_fast * fast[i] + randn(rng)
        end

        # Mix them together
        z = vcat(slow, fast)
        return rotation_matrix * z
    end

    results_decorr = Carlo.merge_results(
        filenames;
        rebin_length = 500,
        sample_skip = 2000,
        estimate_covariance = true,
    )
    decorr_obs = results_decorr[:high_dim]

    τ_sorted = sort(decorr_obs.autocorrelation_time[:])

    # test slow mode
    @test isapprox(τ_sorted[end], τ_slow, rtol = 0.2)

    # test all fast modes
    for i = 1:n_fast
        @test isapprox(τ_sorted[i], τ_fast, rtol = 0.2)
    end
end

@testset "Covariance estimation" begin
    runs = 4
    internal_binsize = 1
    samples_per_run = 40000

    @testset "2D vector observable - known covariance" begin
        rng = Xoshiro(314)
        true_cov = [2.0 0.5; 0.5 1.0]
        L = cholesky(true_cov).L

        filenames, _ = create_mock_data(;
            runs = runs,
            obsname = :corr_vec,
            samples_per_run = samples_per_run,
            internal_binsize = internal_binsize,
        ) do idx
            # this trick generates correlated samples
            z = randn(rng, 2)
            return L * z
        end

        results_no_cov = Carlo.merge_results(filenames; rebin_length = 100)
        @test isnothing(results_no_cov[:corr_vec].covariance)

        results_with_cov =
            Carlo.merge_results(filenames; rebin_length = 100, estimate_covariance = true)
        cov_obs = results_with_cov[:corr_vec]

        @test !isnothing(cov_obs.covariance)
        @test size(cov_obs.covariance) == (2, 2)

        @test diag(cov_obs.covariance) ≈ cov_obs.error .^ 2
        @test cov_obs.covariance[1, 2] ≈ cov_obs.covariance[2, 1]

        # note that Carlo computes cov of mean not "true_cov"
        N_samples = Carlo.rebin_count(cov_obs) * cov_obs.rebin_length
        expected_cov_of_mean = true_cov / N_samples
        for i = 1:2, j = 1:2
            @test isapprox(cov_obs.covariance[i, j], expected_cov_of_mean[i, j], rtol = 0.1)
        end
    end

    @testset "Matrix observable covariance" begin
        rng = Xoshiro(456)

        filenames, _ = create_mock_data(;
            runs = runs,
            obsname = :matrix_obs,
            samples_per_run = samples_per_run,
            internal_binsize = internal_binsize,
        ) do idx
            return randn(rng, 2, 2)
        end

        results =
            Carlo.merge_results(filenames; rebin_length = 50, estimate_covariance = true)
        mat_obs = results[:matrix_obs]

        @test !isnothing(mat_obs.covariance)
        @test size(mat_obs.covariance) == (2, 2, 2, 2)

        for i = 1:2, j = 1:2
            @test mat_obs.covariance[i, j, i, j] ≈ mat_obs.error[i, j]^2
        end

        for i = 1:2, j = 1:2, k = 1:2, l = 1:2
            @test mat_obs.covariance[i, j, k, l] ≈ mat_obs.covariance[k, l, i, j]
        end
    end

    @testset "Scalar observable covariance" begin
        filenames, _ = create_mock_data(;
            runs = runs,
            obsname = :scalar_obs,
            samples_per_run = 5000,
            internal_binsize = internal_binsize,
        ) do idx
            return idx / 100.0
        end

        results =
            Carlo.merge_results(filenames; rebin_length = 10, estimate_covariance = true)
        scalar_obs = results[:scalar_obs]

        @test isnothing(scalar_obs.covariance)
    end

    @testset "Uncorrelated components" begin
        rng = Xoshiro(789)

        filenames, _ = create_mock_data(;
            runs = runs,
            obsname = :uncorr_vec,
            samples_per_run = 50000,
            internal_binsize = internal_binsize,
        ) do idx
            # 3D vector with independent components
            return randn(rng, 3)
        end

        results =
            Carlo.merge_results(filenames; rebin_length = 500, estimate_covariance = true)
        uncorr_obs = results[:uncorr_vec]

        @test !isnothing(uncorr_obs.covariance)
        @test size(uncorr_obs.covariance) == (3, 3)

        # correlation coefficient ρ_{ij} = cov(X,Y) / (σ_X * σ_Y)
        # we test that this is small for the uncorrelated data
        for i = 1:3, j = 1:3
            if i != j
                corr_coef =
                    uncorr_obs.covariance[i, j] /
                    sqrt(uncorr_obs.covariance[i, i] * uncorr_obs.covariance[j, j])
                @test abs(corr_coef) < 0.15
            end
        end
    end
end
