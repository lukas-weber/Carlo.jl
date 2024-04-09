
struct Evaluable{T<:AbstractFloat}
    internal_bin_length::Any
    rebin_length::Int64
    rebin_count::Int64

    mean::Vector{T}
    error::Vector{T}
end

function jackknife(func::Function, sample_set::Tuple{Vararg{AbstractArray,N}}) where {N}
    sample_count = minimum(x -> last(size(x)), sample_set)

    # truncate sample counts to smallest
    sample_set = map(s -> s[axes(s)[1:end-1]..., 1:sample_count], sample_set)

    # the .+0 is a trick to decay 0-dim arrays to scalars
    sums = map(s -> dropdims(sum(s; dims = ndims(s)); dims = ndims(s)) .+ 0, sample_set)

    # evaluation based on complete dataset (truncated to the lowest sample_count)
    complete_eval = func((sums ./ sample_count)...)

    # evaluation on the jacked datasets    
    jacked_eval_mean = zero(complete_eval)
    for k = 1:sample_count
        jacked_means = (
            (sum .- view(samples, axes(samples)[1:end-1]..., k)) ./ (sample_count - 1) for
            (sum, samples) in zip(sums, sample_set)
        )
        jacked_eval_mean += func(jacked_means...)
    end
    jacked_eval_mean /= sample_count

    @assert length(complete_eval) == length(jacked_eval_mean)

    # mean and error
    bias_corrected_mean =
        sample_count * complete_eval .- (sample_count - 1) * jacked_eval_mean

    error = zero(complete_eval)
    for k = 1:sample_count
        jacked_means = (
            (sum .- view(samples, axes(samples)[1:end-1]..., k)) ./ (sample_count - 1) for
            (sum, samples) in zip(sums, sample_set)
        )
        error += (func(jacked_means...) - jacked_eval_mean) .^ 2
    end
    error = sqrt.((sample_count - 1) .* error ./ sample_count)

    return vec(collect(bias_corrected_mean)), vec(collect(error))
end

function evaluate(
    evaluation::Func,
    used_observables::NTuple{N,ResultObservable},
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
        jackknife(evaluation, map(obs -> obs.rebin_means, used_observables))...,
    )
end

function ResultObservable(eval::Evaluable)
    return ResultObservable(
        eval.internal_bin_length,
        eval.rebin_length,
        eval.mean,
        eval.error,
        fill(NaN, size(eval.mean)...),
        eltype(eval.mean)[],
    )
end


struct Evaluator
    observables::Dict{Symbol,ResultObservable}
    evaluables::Dict{Symbol,Evaluable}
end

Evaluator(observables::Dict{Symbol,ResultObservable}) =
    Evaluator(observables, Dict{Symbol,Evaluable}())

"""
    evaluate!(func::Function, eval::Evaluator, name::Symbol, (ingredients::Symbol...))

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
        evaluate(evaluation, tuple((eval.observables[i] for i in ingredients)...))
    return nothing
end
