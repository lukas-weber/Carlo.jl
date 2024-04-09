using Carlo
using Random
using Statistics

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
        samples = zeros(0)
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
                    idx -> [idx, 1.0];
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
                        @test vec_obs.mean ≈ [count_obs.mean[1], 1.0]
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
            expected_autocorrtime = -1 / log(ar1_alpha)
            expected_autocorrtime = 0.5 * (1 + 2 * ar1_alpha / (1 - ar1_alpha))

            @test abs(ar1_obs.mean[1] - expected_mean) < 4 * ar1_obs.error[1]
            @test isapprox(
                ar1_obs.autocorrelation_time[1],
                expected_autocorrtime,
                rtol = 0.1,
            )
        end
    end
end
