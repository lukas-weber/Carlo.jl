module ResultTools

using JSON
using Measurements


make_scalar(x) = isa(x, AbstractVector) && size(x) == (1,) ? only(x) : x

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
                obsname => make_scalar(obs["mean"] .± obs["error"]) for
                (obsname, obs) in t["results"]
            )...,
        ) for t in json
    ]

    return flattened_json
end

end
