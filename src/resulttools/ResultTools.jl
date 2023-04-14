module ResultTools

using JSON
using Measurements


make_scalar(x) = isa(x, AbstractVector) && size(x) == (1,) ? x[1] : x

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
