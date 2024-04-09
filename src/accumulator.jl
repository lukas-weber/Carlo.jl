using HDF5
using ElasticArrays
using Statistics

const binning_output_chunk_size = 1000

mutable struct Accumulator{T<:Number,N,M}
    const bin_length::Int64
    bins::ElasticArray{T,N,M,Vector{T}}

    current_filling::Int64
end

function Accumulator{T}(bin_length::Integer, shape::Tuple{Vararg{Integer}}) where {T}
    if bin_length < 1
        throw(ArgumentError("bin_length ($bin_length) needs to be >= 1"))
    end

    bins = ElasticArray{T}(undef, shape..., 1)
    bins .= 0
    return Accumulator(bin_length, bins, 0)
end

Base.isempty(acc::Accumulator) = num_bins(acc) == 0 && acc.current_filling == 0
has_complete_bins(acc::Accumulator) = num_bins(acc) > 0

Statistics.mean(acc::Accumulator) =
    dropdims(mean(bins(acc); dims = ndims(acc.bins)); dims = ndims(acc.bins))
std_of_mean(acc::Accumulator) = dropdims(
    std(bins(acc); dims = ndims(acc.bins)) / sqrt(num_bins(acc));
    dims = ndims(acc.bins),
)
bins(acc::Accumulator) = Array(@view acc.bins[axes(acc.bins)[1:end-1]..., 1:end-1])
shape(acc::Accumulator) = size(acc.bins)[1:end-1]
num_bins(acc::Accumulator) = size(acc.bins)[end] - 1

function add_sample!(acc::Accumulator, value)
    if size(value) != shape(acc)
        error(
            "size of added value ($(length(value))) does not size of accumulator ($(shape(acc)))",
        )
    end

    current_bin = @view acc.bins[axes(acc.bins)[1:end-1]..., end:end]
    # this one avoids some allocations
    for i in eachindex(value)
        current_bin[i] += value[i]
    end

    acc.current_filling += 1

    if acc.current_filling == acc.bin_length
        current_bin ./= acc.bin_length

        append!(acc.bins, zeros(shape(acc)...))
        acc.current_filling = 0
    end

    return nothing
end

function write_measurements!(acc::Accumulator{T}, out::HDF5.Group) where {T}
    if has_complete_bins(acc)
        if haskey(out, "samples")
            saved_samples = out["samples"]
            old_bin_count = size(saved_samples, ndims(saved_samples))
        else
            out["bin_length"] = acc.bin_length
            saved_samples = create_dataset(
                out,
                "samples",
                eltype(acc.bins),
                ((shape(acc)..., num_bins(acc)), (shape(acc)..., -1));
                chunk = (shape(acc)..., binning_output_chunk_size),
            )
            old_bin_count = 0
        end

        HDF5.set_extent_dims(saved_samples, (shape(acc)..., old_bin_count + num_bins(acc)))
        saved_samples[axes(saved_samples)[1:end-1]..., old_bin_count+1:end] = bins(acc)

        acc.bins = acc.bins[axes(acc.bins)[1:end-1]..., end:end]
    end

    return nothing
end

function write_checkpoint(acc::Accumulator, out::HDF5.Group)
    out["bin_length"] = acc.bin_length
    out["current_bin_filling"] = acc.current_filling
    out["samples"] = Array(acc.bins)
    if size(out["samples"]) == (1, 1)
        attributes(out["samples"])["v0.2_format"] = true
    end

    return nothing
end

function read_checkpoint(::Type{<:Accumulator}, in::HDF5.Group)
    samples = read(in, "samples")

    # this maintains checkpoint compatibility with Carlo v0.1.5. remove in v0.3
    if size(samples) == (1, 1) && !haskey(attributes(in["samples"]), "v0.2_format")
        samples = dropdims(samples; dims = 1)
    end
    return Accumulator(
        read(in, "bin_length"),
        ElasticArray(samples),
        read(in, "current_bin_filling"),
    )
end
