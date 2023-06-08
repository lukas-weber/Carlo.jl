
struct Evaluable{T<:AbstractFloat}
    bin_count::Int64

    mean::Vector{T}
    error::Vector{T}
end

function jackknife(func::Function, sample_set)
    sample_count = minimum(map(x -> size(x, 2), sample_set))
    sums = map(samples -> sum(samples, dims = 2), sample_set)

    # evaluation based on complete dataset (truncated to the lowest sample_count)
    complete_eval = func.(sums ./ sample_count...)

    # evaluation on the jacked datasets    
    jacked_eval_mean = zero(complete_eval)
    for k = 1:sample_count
        jacked_means = (
            (sum .- samples[:, k]) ./ (sample_count - 1) for
            (sum, samples) in zip(sums, sample_set)
        )
        jacked_eval_mean .+= func.(jacked_means...)
    end
    jacked_eval_mean ./= sample_count

    @assert length(complete_eval) == length(jacked_eval_mean)

    # mean and error
    bias_corrected_mean =
        sample_count * complete_eval .- (sample_count - 1) * jacked_eval_mean

    error = zero(complete_eval)
    for k = 1:sample_count
        jacked_means = (
            (sum .- samples[:, k]) ./ (sample_count - 1) for
            (sum, samples) in zip(sums, sample_set)
        )
        error .+= (func.(jacked_means...) .- jacked_eval_mean) .^ 2
    end
    error .= sqrt.((sample_count - 1) * error / sample_count)

    return vec(bias_corrected_mean), vec(error)
end

function evaluate(
    evaluation::Function,
    used_observables::MergedObservable...,
)::Union{Evaluable,Nothing}
    bin_count = minimum(map(obs -> obs.rebin_count, used_observables))

    if bin_count == 0
        return nothing
    end
    return Evaluable(
        bin_count,
        jackknife(
            evaluation,
            map(obs -> obs.rebin_means[:, 1:bin_count], used_observables),
        )...,
    )
end

struct Evaluator{T<:AbstractFloat}
    observables::Dict{Symbol,MergedObservable{T}}
    evaluables::Dict{Symbol,Evaluable{T}}
end

Evaluator(observables::Dict{Symbol,MergedObservable{T}}) where {T} =
    Evaluator(observables, Dict{Symbol,Evaluable{T}}())

function evaluate!(
    evaluation::Function,
    eval::Evaluator,
    name::Symbol,
    ingredients::AbstractArray{Symbol},
)
    eval.evaluables[name] =
        evaluate(evaluation, map(x -> eval.observables[x], ingredients)...)
    return nothing
end
