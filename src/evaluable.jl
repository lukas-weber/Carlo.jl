
struct Evaluable{T<:Number,R<:Real,N,C<:Union{<:AbstractArray, Nothing}}
    internal_bin_length::Int64
    rebin_length::Int64
    rebin_count::Int64

    mean::Array{T,N}
    error::Array{R,N}
    covariance::C
end

function jackknife(func::Function, sample_set::Tuple{Vararg{AbstractArray,N}}, estimate_covariance::Bool) where {N}
    sample_count = minimum(x -> last(size(x)), sample_set)

    # truncate sample counts to smallest
    sample_set = map(s -> s[axes(s)[1:end-1]..., 1:sample_count], sample_set)

    # the .+0 is a trick to decay 0-dim arrays to scalars
    sums = map(s -> dropdims(sum(s; dims = ndims(s)); dims = ndims(s)) .+ 0, sample_set)

    # evaluation based on complete dataset (truncated to the lowest sample_count)
    complete_eval = func((sums ./ sample_count)...)

    # Compute and store all jacked evaluations
    jacked_evals = [
        let jacked_means = (
                (sum .- view(samples, axes(samples)[1:end-1]..., k)) ./ (sample_count - 1) 
                for (sum, samples) in zip(sums, sample_set)
            )
            func(jacked_means...)
        end
        for k in 1:sample_count
    ]

    jacked_eval_mean = sum(jacked_evals) / sample_count
    @assert size(complete_eval) == size(jacked_eval_mean)

    #mean
    bias_corrected_mean =
        sample_count * complete_eval .- (sample_count - 1) * jacked_eval_mean

    #error
    error = sum(abs2.(je - jacked_eval_mean) for je in jacked_evals)
    error = sqrt.((sample_count - 1) .* error ./ sample_count)

    #covariance
    covariance = if estimate_covariance && length(complete_eval)>1
        obs_shape = size(jacked_eval_mean)
        cov_tensor = zeros(eltype(jacked_eval_mean), obs_shape..., obs_shape...)
        prefactor = (sample_count - 1) / sample_count
        for idx1 in CartesianIndices(obs_shape)
            for idx2 in CartesianIndices(obs_shape)
                cov_sum = sum(
                    (je[idx1] - jacked_eval_mean[idx1]) * conj(je[idx2] - jacked_eval_mean[idx2])
                    for je in jacked_evals
                )
                cov_tensor[idx1, idx2] = prefactor * cov_sum
            end
        end
        collect(cov_tensor)
    else
        nothing
    end

    return collect(bias_corrected_mean), collect(error), covariance
end

function evaluate(
    evaluation::Func,
    used_observables::NTuple{N,ResultObservable},
    estimate_covariance::Bool
)::Union{Evaluable,Nothing} where {Func,N}
    internal_bin_length = minimum(obs -> obs.internal_bin_length, used_observables)
    rebin_length = minimum(obs -> obs.rebin_length, used_observables)
    bin_count = minimum(rebin_count, used_observables)

    if bin_count == 0
        return nothing
    end
    return Evaluable(
        internal_bin_length,
        rebin_length,
        bin_count,
        jackknife(evaluation, map(obs -> obs.rebin_means, used_observables),estimate_covariance)...,
    )
end

function ResultObservable(eval::Evaluable)
    return ResultObservable(
        eval.internal_bin_length,
        eval.rebin_length,
        eval.mean,
        eval.error,
        eval.covariance,
        fill(NaN, size(eval.mean)...),
        eltype(eval.mean)[],
    )
end

abstract type AbstractEvaluator end

struct Evaluator <: AbstractEvaluator
    observables::Dict{Symbol,ResultObservable}
    evaluables::Dict{Symbol,Evaluable}
    estimate_covariance::Bool
end

Evaluator(observables::Dict{Symbol,ResultObservable},estimate_covariance::Bool) =
    Evaluator(observables, Dict{Symbol,Evaluable}(),estimate_covariance)

"""
    evaluate!(func::Function, eval::AbstractEvaluator, name::Symbol, (ingredients::Symbol...))

Define an evaluable called `name`, i.e. a quantity depending on the observable averages `ingredients...`. The function `func` will get the ingredients as parameters and should return the value of the evaluable. Carlo will then perform jackknifing to calculate a bias-corrected result with correct error bars that appears together with the observables in the result file.
"""
function evaluate!(
    evaluation::Func,
    eval::Evaluator,
    name::Symbol,
    ingredients::NTuple{N,Symbol},
) where {Func,N}
    notfound = setdiff(ingredients, keys(eval.observables))
    if !isempty(notfound)
        @warn "Evaluable '$name': ingredients $notfound not found. Skipping..."
        return nothing
    end
    eval.evaluables[name] =
        evaluate(evaluation, tuple((eval.observables[i] for i in ingredients)...),eval.estimate_covariance)
    return nothing
end
