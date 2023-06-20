
struct Evaluable{T<:AbstractFloat}
    bin_count::Int64

    mean::Vector{T}
    error::Vector{T}
end

# TODO: remove collect when Julia compatibility rises above ^1.9 
eachcol_or_scalar(M::AbstractMatrix) = size(M, 1) == 1 ? vec(M) : collect(eachcol(M))

function jackknife(func::Function, sample_set)
    sample_count = minimum(map(x -> size(x)[end], sample_set))

    sums = sum.(sample_set)

    # evaluation based on complete dataset (truncated to the lowest sample_count)
    complete_eval = func(sums ./ sample_count...)

    # evaluation on the jacked datasets    
    jacked_eval_mean = zero(complete_eval)
    for k = 1:sample_count
        jacked_means = (
            (sum - samples[k]) ./ (sample_count - 1) for
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
            (sum .- samples[k]) ./ (sample_count - 1) for
            (sum, samples) in zip(sums, sample_set)
        )
        error += (func(jacked_means...) - jacked_eval_mean) .^ 2
    end
    error = sqrt.((sample_count - 1) .* error ./ sample_count)

    return vec(collect(bias_corrected_mean)), vec(collect(error))
end

function evaluate(
    evaluation::Func,
    used_observables::NTuple{N,MergedObservable},
)::Union{Evaluable,Nothing} where {Func,N}
    bin_count = minimum(map(obs -> obs.rebin_count, used_observables))

    if bin_count == 0
        return nothing
    end
    return Evaluable(
        bin_count,
        jackknife(
            evaluation,
            map(
                obs -> eachcol_or_scalar(obs.rebin_means[:, 1:bin_count]),
                used_observables,
            ),
        )...,
    )
end

struct Evaluator{T<:AbstractFloat}
    observables::Dict{Symbol,MergedObservable{T}}
    evaluables::Dict{Symbol,Evaluable{T}}
end

Evaluator(observables::Dict{Symbol,MergedObservable{T}}) where {T} =
    Evaluator(observables, Dict{Symbol,Evaluable{T}}())

"""
    evaluate!(func::Function, eval::Evaluator, name::Symbol, (ingredients::Symbol...))

Define an evaluable called `name`, i.e. a quantity depending on the observable averages `ingredients...`. The function `func` will get the ingredients as parameters and should return the value of the evaluable. LoadLeveller will then perform jackknifing to calculate a bias-corrected result with correct error bars that appears together with the observables in the result file.
"""
function evaluate!(
    evaluation::Func,
    eval::Evaluator,
    name::Symbol,
    ingredients::NTuple{N,Symbol},
) where {Func,N}
    eval.evaluables[name] =
        evaluate(evaluation, tuple((eval.observables[i] for i in ingredients)...))
    return nothing
end
