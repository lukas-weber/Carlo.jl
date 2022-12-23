using LoadLeveller
using Formatting

@testset "Merge" begin
    tmpdir = mktempdir()
    walkers = 4

    for internal_binsize in [1 3 4]
        for samples_per_walker in [4 5 10]
            extra_samples = 20
            total_samples = walkers * samples_per_walker + extra_samples

            @testset "samples = $(total_samples), binsize = $(internal_binsize)" begin

                samples = zeros(0)

                filenames = map(x -> format("{}/walker{}.h5", tmpdir, x), 1:walkers)

                idx = 1
                internal_binsize = 4
                for walker = 1:walkers
                    h5open(filenames[walker], "w") do file
                        meas = LoadLeveller.Measurements{Float64}(internal_binsize)
                        nsamples = samples_per_walker + extra_samples * (walker == 1)
                        for i = 1:nsamples
                            LoadLeveller.add_sample!(meas, :test, idx)
                            if i <= (nsamples ÷ internal_binsize) * internal_binsize
                                append!(samples, idx)
                            end
                            idx += 1
                        end
                        LoadLeveller.write_measurements!(
                            meas,
                            create_group(file, "observables"),
                        )
                    end
                end

                for rebin_length in [nothing, 1, 2]
                    results = LoadLeveller.merge_results(
                        filenames,
                        data_type = Float64,
                        rebin_length = rebin_length,
                    )
                    obs = results[:test]

                    rebinned_samples = samples[1:(length(
                        samples,
                    )÷(obs.rebin_length*obs.rebin_count)*(obs.rebin_length*obs.rebin_count))]

                    @test obs.total_sample_count == length(samples) ÷ internal_binsize
                    @test obs.mean[1] ≈ sum(rebinned_samples) / length(rebinned_samples)
                    if rebin_length != nothing
                        @test obs.rebin_length == rebin_length
                    else
                        @test 1 <
                              obs.rebin_length * obs.rebin_count <=
                              obs.total_sample_count
                    end
                end
            end
        end
    end
end
