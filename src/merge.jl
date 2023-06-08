using Logging

"""Determine the number of bins in the rebin procedure. Rebinning will not be performed if the number of samples is smaller than `min_bin_count`."""
function calc_rebin_count(sample_count::Integer, min_bin_count::Integer = 10)::Integer
    return sample_count <= min_bin_count ? sample_count :
           (min_bin_count + round(cbrt(sample_count - min_bin_count)))
end

mutable struct MergedObservable{T<:AbstractFloat}
    internal_bin_length::Int64
    total_sample_count::Int64

    rebin_count::Int64
    rebin_length::Int64

    current_rebin::Int64
    current_rebin_filling::Int64
    sample_counter::Int64

    mean::Vector{T}
    error::Vector{T}
    autocorrelation_time::Vector{T}

    rebin_means::Array{T,2}
end

function MergedObservable{T}(internal_bin_length::Integer, vector_size::Integer) where {T}
    return MergedObservable{T}(
        internal_bin_length,
        0,
        0,
        0,
        1,
        0,
        0,
        zeros(T, vector_size),
        zeros(T, vector_size),
        zeros(T, vector_size),
        Array{T,2}(undef, 0, 0),
    )
end


function merge_results(
    filenames::AbstractArray{<:AbstractString};
    data_type::Type{T},
    rebin_length::Union{Integer,Nothing},
    sample_skip::Integer = 0,
) where {T<:AbstractFloat}
    observables = Dict{Symbol,MergedObservable{T}}()

    for filename in filenames
        h5open(filename, "r") do meas_file
            for obs_name in keys(meas_file["observables"])
                try
                    obs_group = meas_file["observables"][obs_name]
                    internal_bin_length = read(obs_group, "bin_length")[1]

                    samples = read(obs_group, "samples")

                    obs_symb = Symbol(obs_name)
                    if !haskey(observables, obs_symb)
                        observables[obs_symb] = MergedObservable{eltype(samples)}(
                            internal_bin_length,
                            size(samples, 1),
                        )
                    end
                    obs = observables[obs_symb]

                    sample_size = size(samples, 2)
                    obs.total_sample_count += sample_size - min(sample_size, sample_skip)
                catch err
                    if isa(err, KeyError)
                        @warn "$(obs_name): $(err). Skipping..."
                    else
                        throw(err)
                    end
                end
            end
        end
    end

    for (obs_name, obs) in observables
        if rebin_length !== nothing
            obs.rebin_length = rebin_length
            obs.rebin_count = obs.total_sample_count ÷ obs.rebin_length
        else
            obs.rebin_count = calc_rebin_count(obs.total_sample_count)
            obs.rebin_length = obs.total_sample_count ÷ obs.rebin_count
        end
        obs.rebin_means = zeros(eltype(obs.mean), size(obs.mean, 1), obs.rebin_count)
    end

    for filename in filenames
        h5open(filename, "r") do meas_file
            g = meas_file["observables"]
            for (obs_name, obs) in observables
                obs_name_str = String(obs_name)
                if !haskey(g, obs_name_str)
                    continue
                end

                samples = read(g, obs_name_str * "/samples")

                remaining_samples = obs.rebin_count * obs.rebin_length - obs.sample_counter

                sample_start = 1 + sample_skip
                sample_end = min(size(samples, 2), remaining_samples)
                obs.mean .+= vec(sum(samples[:, sample_start:sample_end], dims = 2))
                obs.sample_counter += length(sample_start:sample_end)
            end
        end
    end

    for (obs_name, obs) in observables
        if obs.rebin_count == 0
            continue
        end

        obs.mean /= obs.rebin_count * obs.rebin_length

        @assert obs.sample_counter == obs.rebin_count * obs.rebin_length
        obs.sample_counter = 0
    end

    for filename in filenames
        h5open(filename, "r") do meas_file
            g = meas_file["observables"]
            for (obs_name, obs) in observables
                obs_name_str = String(obs_name)
                if !haskey(g, obs_name_str)
                    continue
                end

                samples = read(g, obs_name_str * "/samples")
                remaining_samples = obs.rebin_count * obs.rebin_length - obs.sample_counter

                sample_start = 1 + sample_skip
                sample_end = min(size(samples, 2), remaining_samples)

                for s = sample_start:sample_end
                    obs.rebin_means[:, obs.current_rebin] .+= samples[:, s]

                    # Using autocorrelation_time as a buffer for the naive no-rebinning error here
                    obs.autocorrelation_time += (samples[:, s] - obs.mean) .^ 2

                    obs.current_rebin_filling += 1
                    if obs.current_rebin_filling >= obs.rebin_length
                        obs.rebin_means[obs.current_rebin] /= obs.rebin_length
                        diff = obs.rebin_means[obs.current_rebin] .- obs.mean
                        obs.error .+= diff .^ 2

                        obs.current_rebin += 1
                        obs.current_rebin_filling = 0
                    end
                    obs.sample_counter += 1
                end
            end
        end
    end

    for (obs_name, obs) in observables
        @assert obs.current_rebin == obs.rebin_count + 1
        @assert obs.sample_counter == obs.rebin_count * obs.rebin_length

        used_samples = obs.rebin_count * obs.rebin_length
        no_rebinning_error =
            sqrt.(obs.autocorrelation_time ./ ((used_samples - 1) * used_samples))

        obs.error = sqrt.(obs.error ./ ((obs.rebin_count - 1) * obs.rebin_count))
        obs.autocorrelation_time = 0.5 * (obs.error ./ no_rebinning_error) .^ 2
    end

    return observables
end
