using Random

function write_rng_checkpoint!(rng::Random.Xoroshiro, check_file::HDF5.Group)
    check_file["type"] = "xoroshiro256++"
    check_file["state"] = (rng.s0, rng.s1, rng.s2, rng.s3)
    check_file["rng_version"] = 1
    
    return nothing
end

function read_rng_checkpoint(check_file::HDF5.Group)::Random.AbstractRNG
    rng_type = check_file["type"] == "xoroshiro256++"
    if rng_type
        s0, s1, s2, s3 = check_file["state"]
        return Random.Xoroshiro(s0, s1, s2, s3)
    end
    
    error("unknown rng type '$rng_type'")
end