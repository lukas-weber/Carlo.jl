using Random
using Printf
using Serialization

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
function step!(run::Run, comm::MPI.Comm = MPI.COMM_NULL)
    sweep!(run.implementation, run.context, comm)
    run.context.sweeps += 1
    if is_thermalized(run.context)
        measure!(run.implementation, run.context, comm)
        return 1
    end
    return 0
end

function write_checkpoint!(
    run::Run,
    file_prefix::AbstractString,
    comm::MPI.Comm = MPI.COMM_NULL,
)
    checkpoint_write_time = @elapsed begin
        if comm == MPI.COMM_NULL || MPI.Comm_rank(comm) == 0
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
        end

        if comm == MPI.COMM_NULL
            h5open(file_prefix * ".dump.h5.tmp", "w") do file
                write_checkpoint(run.context, create_group(file, "context/0001"))
                write_checkpoint(run.implementation, create_group(file, "simulation"))
                write_hdf5(
                    Version(typeof(run.implementation)),
                    create_group(file, "version"),
                )
            end
        else
            is_run_leader = MPI.Comm_rank(comm) == 0
            buf = IOBuffer()
            serialize(buf, run.context)

            serialized_context = take!(buf)
            lengths = MPI.Gather(length(serialized_context), comm)

            if !is_run_leader
                MPI.Gatherv!(serialized_context, nothing, comm)
                write_checkpoint(run.implementation, nothing, comm)
            else
                h5open(file_prefix * ".dump.h5.tmp", "w") do file
                    vbuffer =
                        is_run_leader ?
                        MPI.VBuffer(Vector{UInt8}(undef, sum(lengths)), lengths) :
                        nothing
                    MPI.Gatherv!(serialized_context, vbuffer, comm)

                    buf = IOBuffer(vbuffer.data)
                    for i in eachindex(lengths)
                        write_checkpoint(
                            deserialize(buf),
                            create_group(file, @sprintf "context/%04d" i),
                        )
                    end

                    write_checkpoint(
                        run.implementation,
                        create_group(file, "simulation"),
                        comm,
                    )
                    write_hdf5(
                        Version(typeof(run.implementation)),
                        create_group(file, "version"),
                    )
                end
            end
        end
    end

    if comm == MPI.COMM_NULL || MPI.Comm_rank(comm) == 0
        add_sample!(run.context.measure, :_ll_checkpoint_write_time, checkpoint_write_time)
    end

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
    comm::MPI.Comm = MPI.COMM_NULL,
)::Union{Run{MC,RNG},Nothing} where {MC,RNG}
    if !isfile(file_prefix * ".dump.h5")
        return nothing
    end

    context = nothing
    mc = nothing

    checkpoint_read_time = @elapsed begin
        mc = MC(parameters)
        h5open(file_prefix * ".dump.h5", "r") do file
            if comm == MPI.COMM_NULL
                context = read_checkpoint(MCContext{RNG}, file["context/0001"])
                read_checkpoint!(mc, file["simulation"])
            else
                context = read_checkpoint(
                    MCContext{RNG},
                    file[@sprintf "context/%04d" MPI.Comm_rank(comm)],
                )
                read_checkpoint!(mc, file["simulation"], comm)
            end
        end
    end

    if comm == MPI.COMM_NULL || MPI.Comm_rank(comm) == 0
        add_sample!(context.measure, :_ll_checkpoint_read_time, checkpoint_read_time)
    end

    return Run(context, mc)
end
