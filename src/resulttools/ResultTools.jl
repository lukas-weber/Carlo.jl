module ResultTools

using JSON
using Measurements

make_scalar(x) = x isa AbstractVector && size(x) == (1,) ? only(x) : x

# JSON turns arrays into Vector{Any}s of Vector{Any}s. This function undoes this by recursively stacking the vectors.
recursive_stack(v) = v

# this converts all Vector{AbstractDict} to Vector{Complex}
function recursive_stack(v::AbstractDict)
    if haskey(v, "re") && haskey(v, "im")
        return Complex(v["re"], v["im"])
    else
        throw("Expected a JSON object with 're' and 'im' keys, got: $v")
    end
end

function recursive_stack(v::AbstractArray)
    if ndims(v) == 0 || any(isnothing, v)
        return v
    end
    return stack(recursive_stack, v)
end

function measurement_from_obs(obsname, obs)
    if ismissing(obs)
        return missing
    end
    if !isnothing(obs["rebin_len"]) &&
       !isnothing(obs["autocorr_time"]) &&
       obs["autocorr_time"] >= obs["rebin_len"]
        @warn "$obsname: autocorrelation time longer than rebin length. Results may be unreliable."
    end

    mean = obs["mean"]
    error = obs["error"]

    mean = recursive_stack(mean)
    error = recursive_stack(error)

    sanitize(m, e) = (isnothing(m) || isnothing(e)) ? missing : m ± e
    sanitize(m::Complex, e) =
        (isnothing(m) || isnothing(e)) ? missing : Complex(real(m) ± e, imag(m))
    return make_scalar(sanitize.(mean, error))
end

"""
    ResultTools.dataframe(result_json::AbstractString)

Helper to import result data from a `*.results.json` file produced after a Carlo calculation. Returns a Tables.jl-compatible dictionary that can be used as is or converted into a DataFrame or other table structure. Observables and their errorbars will be converted to Measurements.jl measurements.
"""
function dataframe(result_json::AbstractString)
    json = JSON.parsefile(result_json)

    obsnames = unique(Iterators.flatten(keys(t["results"]) for t in json))
    flattened_json = Dict{String,Any}[
        Dict(
            "task" => basename(t["task"]),
            t["parameters"]...,
            Dict(
                obsname =>
                    measurement_from_obs(obsname, get(t["results"], obsname, missing))
                for obsname in obsnames
            )...,
        ) for t in json
    ]

    return flattened_json
end

end
