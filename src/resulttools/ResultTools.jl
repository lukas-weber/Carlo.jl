module ResultTools

using JSON
using Measurements


make_scalar(x) = x isa AbstractVector && size(x) == (1,) ? only(x) : x

function measurement_from_obs(obsname, obs)
    if obs["rebin_length"] !== nothing && obs["autocorr_time"] >= obs["rebin_length"]
        @warn "$obsname: autocorrelation time longer than rebin length. Results may be unreliable."
    end

    mean = obs["mean"]
    error = obs["error"]
    if isnothing(mean) || isnothing(error)
        return missing
    end

    return make_scalar(mean .± error)
end

"""
    ResultTools.dataframe(result_json::AbstractString)

Helper to import result data from a `*.results.json` file produced after a LoadLeveller calculation. Returns a Tables.jl-compatible dictionary that can be used as is or converted into a DataFrame or other table structure. Observables and their errorbars will be converted to Measurements.jl measurements.
"""
function dataframe(result_json::AbstractString)
    json = JSON.parsefile(result_json)

    flattened_json = Dict{String,Any}[
        Dict(
            "task" => basename(t["task"]),
            t["parameters"]...,
            Dict(
                obsname => measurement_from_obs(obsname, obs) for
                (obsname, obs) in t["results"]
            )...,
        ) for t in json
    ]

    return flattened_json
end

end
