mutable struct Observable
    name::String

    bin_length::Int64
    current_bin_filling::Int64

    samples::Array{Float64,2}

    function Observable(name::AbstractString, bin_length::Integer, vector_length::Integer)
        samples = Array{Float64,2}(undef, vector_length, 1)
        samples[1, 1] = 0
        return new(name, bin_length, 0, samples)
    end

end

function add_sample!(obs::Observable, value)
    if length(val) != size(obs.samples, 1)
        error(
            "length of added value ($(length(val))) does not fit length of observable ($(size(obs.samples,1)))",
        )
    end

    obs.samples[:, end] += val[:]
    obs.current_bin_filling += 1

    if obs.current_bin_filling == obs.bin_length
        if obs.bin_length > 1
            obs.samples[:, end] /= obs.bin_length
        end

        # XXX: is this too slow?
        obs.samples = hcat(obs.samples, zeros(size(obs.samples, 1)))
        obs.current_bin_filling = 0
    end

    return nothing
end
