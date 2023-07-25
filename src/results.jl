import JSON

"""Result of a Carlo Monte Carlo calculation containing the mean, statistical error and autocorrelation time."""
struct ResultObservable{T<:AbstractFloat}
    rebin_count::Int64
    rebin_length::Union{Int64,Nothing}
    internal_bin_length::Union{Int64,Nothing}

    mean::Vector{T}
    error::Vector{T}
    autocorrelation_time::T
end

function ResultObservable(mobs::MergedObservable)
    return ResultObservable(
        mobs.rebin_count,
        mobs.rebin_length,
        mobs.internal_bin_length,
        mobs.mean,
        mobs.error,
        maximum(mobs.autocorrelation_time),
    )
end

function ResultObservable(eval::Evaluable)
    return ResultObservable(eval.bin_count, nothing, nothing, eval.mean, eval.error, NaN)
end


JSON.lower(obs::ResultObservable) = Dict(
    "mean" => obs.mean,
    "error" => obs.error,
    "autocorr_time" => obs.autocorrelation_time,
    "rebin_len" => obs.rebin_length,
    "rebin_count" => obs.rebin_count,
    "internal_bin_len" => obs.internal_bin_length,
)


function write_results(
    observables::Dict{Symbol,ResultObservable{T}},
    filename::AbstractString,
    taskdir::AbstractString,
    parameters::Dict,
    version::Version,
) where {T}
    open(filename, "w") do file
        JSON.print(
            file,
            Dict(
                "task" => taskdir,
                "parameters" => parameters,
                "results" => observables,
                "version" => to_dict(version),
            ),
            1,
        )
    end
    return nothing
end
