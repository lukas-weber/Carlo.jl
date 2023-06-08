using Random

struct Run{MC<:AbstractMC,RNG<:Random.AbstractRNG}
    context::MCContext{RNG}
    implementation::MC
end

function Run{MC,RNG}(params::Dict) where {MC,RNG}
    context = MCContext{RNG}(params)
    implementation = MC(params)
    init!(implementation, context, params)

    return Run(context, implementation)
end


"""Perform one MC step. This will return the number of thermalized sweeps performed"""
function step!(run::Run)
    sweep!(run.implementation, run.context)
    run.context.sweeps += 1
    if is_thermalized(run.context)
        measure!(run.implementation, run.context)
        return 1
    end
    return 0
end

function write_checkpoint!(run::Run, file_prefix::AbstractString)
    checkpoint_write_time = @elapsed begin
        try
            cp(file_prefix * ".meas.h5", file_prefix * ".meas.h5.tmp", force = true)
        catch e
            if !isa(e, Base.IOError)
                rethrow()
            end
        end

        h5open(file_prefix * ".meas.h5.tmp", "cw") do file
            write_measurements!(run.context, file["/"])
            write_hdf5(
                Version(typeof(run.implementation)),
                create_absent_group(file, "version"),
            )
        end

        h5open(file_prefix * ".dump.h5.tmp", "w") do file
            write_checkpoint(run.context, create_group(file, "context"))
            write_checkpoint(run.implementation, create_group(file, "simulation"))
            write_hdf5(Version(typeof(run.implementation)), create_group(file, "version"))
        end
    end

    add_sample!(run.context.measure, :_ll_checkpoint_write_time, checkpoint_write_time)

    return nothing
end

function write_checkpoint_finalize(file_prefix::AbstractString)
    mv(file_prefix * ".dump.h5.tmp", file_prefix * ".dump.h5", force = true)
    mv(file_prefix * ".meas.h5.tmp", file_prefix * ".meas.h5", force = true)

    return nothing
end

function read_checkpoint(
    ::Type{Run{MC,RNG}},
    file_prefix::AbstractString,
    parameters::Dict,
)::Union{Run{MC,RNG},Nothing} where {MC,RNG}
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

    add_sample!(context.measure, :_ll_checkpoint_read_time, checkpoint_read_time)
    return Run(context, mc)
end
