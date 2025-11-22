import JSON

"""Result of a Carlo Monte Carlo calculation containing the mean, statistical error and autocorrelation time."""
mutable struct ResultObservable{T<:Number,R<:Real,N,M,L}
    internal_bin_length::Int64
    rebin_length::Int64

    mean::Array{T,N}
    error::Array{R,N}
    covariance::Union{Array{T,L},Nothing}
    autocorrelation_time::Array{R,N}

    rebin_means::Array{T,M}

    function ResultObservable(
        internal_bin_length::Int64,
        rebin_length::Int64,
        mean::Array{T,N},
        error::Array{R,N},
        covariance::Array{R,L},
        autocorrelation_time::Array{R,N},
        rebin_means::Array{T,M},
    ) where {T<:Number,R<:Real,N,M,L}
        new{T,R,N,M,L}(internal_bin_length, rebin_length, mean, error, covariance, autocorrelation_time, rebin_means)
    end
    
    function ResultObservable(
        internal_bin_length::Int64,
        rebin_length::Int64,
        mean::Array{T,N},
        error::Array{R,N},
        covariance::Nothing,
        autocorrelation_time::Array{R,N},
        rebin_means::Array{T,M},
    ) where {T<:Number,R<:Real,N,M}
        new{T,R,N,M,0}(internal_bin_length, rebin_length, mean, error, nothing, autocorrelation_time, rebin_means)
    end
end

rebin_count(obs::ResultObservable) = Int64(size(obs.rebin_means)[end])

JSON.lower(obs::ResultObservable) = Dict(
    "mean" => obs.mean,
    "error" => obs.error,
    "covariance" => obs.covariance,
    "autocorr_time" => maximum(obs.autocorrelation_time),
    "rebin_len" => obs.rebin_length,
    "rebin_count" => rebin_count(obs),
    "internal_bin_len" => obs.internal_bin_length,
)


function write_results(
    observables::AbstractDict,
    filename::AbstractString,
    taskdir::AbstractString,
    parameters::Dict,
    version::Version,
)
    open(filename, "w") do file
        JSON.json(
            file,
            Dict(
                "task" => taskdir,
                "parameters" => parameters,
                "results" => observables,
                "version" => to_dict(version),
            ); pretty = 1, allownan = true
        )
    end
    return nothing
end
