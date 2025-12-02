import JSON

"""Result of a Carlo Monte Carlo calculation containing the mean, statistical error and autocorrelation time."""
mutable struct ResultObservable{T<:Number,R<:Real,N,M,C<:Union{<:AbstractArray,Nothing}}
    internal_bin_length::Int64
    rebin_length::Int64

    mean::Array{T,N}
    error::Array{R,N}
    covariance::C
    autocorrelation_time::Array{R,N}

    rebin_means::Array{T,M}
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
