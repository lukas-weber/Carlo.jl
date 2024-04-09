using Logging
using Statistics

"""Determine the number of bins in the rebin procedure. Rebinning will not be performed if the number of samples is smaller than `min_bin_count`."""
function calc_rebin_count(sample_count::Integer, min_bin_count::Integer = 10)::Integer
    return sample_count <= min_bin_count ? sample_count :
           (min_bin_count + round(cbrt(sample_count - min_bin_count)))
end

function calc_rebin_length(total_sample_count, rebin_length)
    if total_sample_count == 0
        return 0
    elseif rebin_length !== nothing
        return rebin_length
    else
        return total_sample_count ÷ calc_rebin_count(total_sample_count)
    end
end

mutable struct Accumulator{T,N,M}
    const binsize::Int64

    const bins::ElasticArray{T,N,M,Vector{T}}
    current_filling::Int64
end

Accumulator{T}(shape::Tuple{Vararg{Integer}}, binsize) where {T} =
    Accumulator{T,length(shape) + 1,length(shape)}(
        binsize,
        ElasticMatrix(zeros(T, shape..., 1)),
        0,
    )

function add!(acc::Accumulator, value)
    acc.bins[axes(acc.bins)[1:end-1]..., end] .+= value
    acc.current_filling += 1

    if acc.current_filling == acc.binsize
        acc.bins[axes(acc.bins)[1:end-1]..., end] ./= acc.binsize
        acc.current_filling = 0
        append!(acc.bins, zeros(eltype(acc.bins), axes(acc.bins)[1:end-1]...))
    end
end

Statistics.mean(acc::Accumulator) =
    dropdims(mean(bins(acc); dims = ndims(acc.bins)); dims = ndims(acc.bins))
std_of_mean(acc::Accumulator) = dropdims(
    std(bins(acc); dims = ndims(acc.bins)) / sqrt(num_bins(acc));
    dims = ndims(acc.bins),
)
bins(acc::Accumulator) = Array(@view acc.bins[axes(acc.bins)[1:end-1]..., 1:end-1])
num_bins(acc::Accumulator) = size(acc.bins)[end] - 1
num_samples(acc::Accumulator) = acc.binsize * num_bins(acc)

"""
This helper function consecutively opens all ".meas.h5" files of a task. For each
observable in the file, it calls

    states[obs_key] = func(obs_key, obs, get(states, obs_key, nothing))

Finally the dictionary `states` is returned. This construction allows `func` to only care about a single observable, simplifying the merging code.
"""
function iterate_measfile_observables(func::Func, filenames) where {Func}
    states = Dict{Symbol,Any}()
    for filename in filenames
        h5open(filename, "r") do meas_file
            for obs_name in keys(meas_file["observables"])
                obs_key = Symbol(obs_name)
                obs = nothing
                try
                    obs = meas_file["observables"][obs_name]
                catch err
                    if err isa KeyError
                        @warn "$(obs_name): $(err). Skipping..."
                        continue
                    end
                    rethrow(err)
                end
                states[obs_key] = func(obs_key, obs, get(states, obs_key, nothing))
            end
        end
    end
    return states
end

function merge_results(
    filenames::AbstractArray{<:AbstractString},
    ::Type{T} = Float64;
    rebin_length::Union{Integer,Nothing},
    sample_skip::Integer = 0,
) where {T<:AbstractFloat}
    obs_types = iterate_measfile_observables(filenames) do _, obs_group, state
        internal_bin_length = read(obs_group, "bin_length")
        sample_size = size(obs_group["samples"])

        shape = sample_size[1:end-1]
        nsamples = max(0, sample_size[end] - sample_skip)

        type = eltype(obs_group["samples"])

        if isnothing(state)
            return (; T = type, internal_bin_length, shape, total_sample_count = nsamples)
        end
        if shape != state.shape
            error("Observable shape ($shape) does not agree between runs ($(state.shape))")
        end

        return (;
            T = promote_type(state.T, type),
            internal_bin_length = state.internal_bin_length,
            shape = state.shape,
            total_sample_count = state.total_sample_count + nsamples,
        )
    end

    binned_obs = iterate_measfile_observables(filenames) do obs_name, obs_group, state
        obs_type = obs_types[obs_name]

        if state === nothing
            binsize = calc_rebin_length(obs_type.total_sample_count, rebin_length)
            state = (;
                acc = Accumulator{obs_type.T}(obs_type.shape, binsize),
                acc² = Accumulator{obs_type.T}(obs_type.shape, binsize),
            )
        end

        samples = read(obs_group, "samples")
        for value in Iterators.drop(eachslice(samples; dims = ndims(samples)), sample_skip)
            add!(state.acc, value)
            add!(state.acc², abs2.(value))
        end

        return state
    end

    return Dict{Symbol,ResultObservable}(
        obs_name => begin
            μ = mean(obs.acc)
            σ = std_of_mean(obs.acc)

            no_rebinning_σ =
                sqrt.(max.(0, mean(obs.acc²) .- abs2.(μ)) ./ (num_samples(obs.acc) - 1))
            autocorrelation_time = 0.5 .* (σ ./ no_rebinning_σ) .^ 2

            ResultObservable(
                obs_types[obs_name].internal_bin_length,
                obs.acc.binsize,
                μ,
                σ,
                autocorrelation_time,
                bins(obs.acc),
            )
        end for (obs_name, obs) in binned_obs if num_bins(obs.acc) > 0
    )
end
