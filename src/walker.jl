using Random

struct Walker{MC<:AbstractMC,RNG<:Random.AbstractRNG}
    context::MCContext{RNG}
    impl::MC
end

function Walker{MC,RNG}(params::Dict) where {MC,RNG}
    context = MCContext{RNG}(params)
    impl = MC(params)
    init!(impl, context, params)

    return Walker(context, impl)
end


"""Perform one MC step. This will return the number of thermalized sweeps performed"""
function step!(w::Walker)
    sweep!(w.impl, w.context)
    w.context.sweeps += 1
    if is_thermalized(w.context)
        measure!(w.impl, w.context)
        return 1
    end
    return 0
end


function write_checkpoint(w::Walker, file_prefix::AbstractString)
    checkpoint_write_time = @elapsed begin
        try
            cp(file_prefix * ".meas.h5", file_prefix * ".meas.h5.tmp", force = true)
        catch e
            if !isa(e, Base.IOError)
                rethrow()
            end
        end

        h5open(file_prefix * ".meas.h5.tmp", "cw") do file
            write_measurements!(w.context, file["/"])
        end

        h5open(file_prefix * ".dump.h5.tmp", "w") do file
            write_checkpoint!(w.context, create_group(file, "context"))
            write_checkpoint!(w.impl, create_group(file, "simulation"))
        end
    end

    add_sample!(w.context.measure, :_ll_checkpoint_write_time, checkpoint_write_time)

    return nothing
end

function write_checkpoint_finalize(file_prefix::AbstractString)
    mv(file_prefix * ".dump.h5.tmp", file_prefix * ".dump.h5", force = true)
    mv(file_prefix * ".meas.h5.tmp", file_prefix * ".meas.h5", force = true)

    return nothing
end

function read_checkpoint(
    ::Type{Walker{MC,RNG}},
    file_prefix::AbstractString,
    parameters::Dict,
)::Union{Walker{MC,RNG},Nothing} where {MC,RNG}
    if !isfile(file_prefix * ".dump.h5")
        return nothing
    end

    context = nothing
    mc = nothing

    checkpoint_read_time = @elapsed begin
        h5open(file_prefix * ".dump.h5", "r") do file
            context = read_checkpoint(MCContext{RNG}, file["context"])

            mc = MC(parameters)
            read_checkpoint!(mc, file["simulation"])
        end
    end

    add_sample!(context.measure, "__ll_checkpoint_read_time", checkpoint_read_time)
    return Walker(context, mc)
end
