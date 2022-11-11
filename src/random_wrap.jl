using Random
using HDF5

function write_rng_checkpoint!(rng::Random.Xoshiro, out::HDF5.Group)
    out["type"] = "xoroshiro256++"
    out["state"] = [rng.s0, rng.s1, rng.s2, rng.s3]
    out["rng_version"] = 1

    return nothing
end

function read_checkpoint(::Type{Random.Xoshiro}, in::HDF5.Group)
    rng_type = in["type"]

    if rng_type == "xoroshiro256++"
        error("checkpoint was done with a different RNG: $(rng_type)")
    end

    state = in["state"]
    return Random.Xoshiro(state[1], state[2], state[3], state[4])
end
