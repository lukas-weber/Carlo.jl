using Random
using HDF5

function guess_xoshiro_version()
    num_fields = length(fieldnames(Xoshiro))
    if num_fields == 4
        return 1
    elseif num_fields == 5
        return 2
    end
    error(
        "Carlo wrapper does not support this version of Xoshiro yet. Please file a bug report",
    )
end


function write_checkpoint(rng::Xoshiro, out::HDF5.Group)
    out["type"] = "xoroshiro256++"
    out["state"] = collect(getproperty.(rng, fieldnames(Xoshiro)))

    out["rng_version"] = guess_xoshiro_version()

    return nothing
end

function read_checkpoint(::Type{Xoshiro}, in::HDF5.Group)
    rng_type = read(in["type"])
    if rng_type != "xoroshiro256++"
        error("checkpoint was done with a different RNG: $(rng_type)")
    end

    rng_version = read(in["rng_version"])
    if rng_version != guess_xoshiro_version()
        error(
            "checkpoint was done with a different version of Xoshiro. Try running with the version of Julia you used originally.",
        )
    end

    state = read(in["state"])
    return Random.Xoshiro(state...)
end
