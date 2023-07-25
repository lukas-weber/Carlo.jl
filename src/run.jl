using Random
using Printf
using Serialization

struct Run{MC<:AbstractMC,RNG<:Random.AbstractRNG}
    context::MCContext{RNG}
    implementation::MC
end

function Run{MC,RNG}(
    params::Dict,
    comm::MPI.Comm = MPI.COMM_NULL,
) where {MC<:AbstractMC,RNG<:AbstractRNG}
    context = MCContext{RNG}(params)
    implementation = MC(params)
    init!(implementation, context, params, comm)

    return Run{MC,RNG}(context, implementation)
end

"""Perform one MC step. Returns the number of thermalized sweeps performed"""
function step!(run::Run, comm::MPI.Comm = MPI.COMM_NULL)
    sweep_time = @elapsed sweep!(run.implementation, run.context, comm)
    run.context.sweeps += 1
    if is_thermalized(run.context)
        measure_time = @elapsed measure!(run.implementation, run.context, comm)

        if comm == MPI.COMM_NULL || MPI.Comm_rank(comm) == 0
            measure!(run.context, :_ll_sweep_time, sweep_time)
            measure!(run.context, :_ll_measure_time, measure_time)
        end

        return 1
    end

    if comm != MPI.COMM_NULL && MPI.Comm_rank(comm) != 0
        if !isempty(run.context.measure)
            error(
                "In parallel run mode, only the first rank of the run communicator is allowed to do measurements!",
            )
        end
    end
    return 0
end

function write_measurements(run::Run, file_prefix::AbstractString)
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

    @assert !has_complete_bins(run.context.measure)
end

function write_checkpoint!(
    run::Run,
    file_prefix::AbstractString,
    comm::MPI.Comm = MPI.COMM_NULL,
)
    checkpoint_write_time = @elapsed begin
        if comm == MPI.COMM_NULL || MPI.Comm_rank(comm) == 0
            write_measurements(run, file_prefix)
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

            if !is_run_leader && !isempty(run.context.measure)
                error("In parallel run mode, only the first rank of a run can do measurements!")
            end

            if !is_run_leader
                MPI.send(run.context, comm; dest = 0, tag = T_MCCONTEXT)
                write_checkpoint(run.implementation, nothing, comm)
            else
                h5open(file_prefix * ".dump.h5.tmp", "w") do file
                    write_checkpoint(run.context, create_group(file, "context/0001"))
                    for _ = 1:MPI.Comm_size(comm)-1
                        context, status = MPI.recv(comm, MPI.Status; tag = T_MCCONTEXT)

                        write_checkpoint(
                            context,
                            create_group(file, @sprintf("context/%04d", status.source + 1)),
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
)::Union{Run{MC,RNG},Nothing} where {MC,RNG}
    if !isfile(file_prefix * ".dump.h5")
        return nothing
    end

    context = nothing

    mc = MC(parameters)
    checkpoint_read_time = @elapsed begin
        h5open(file_prefix * ".dump.h5", "r") do file
            context = read_checkpoint(MCContext{RNG}, file["context/0001"])
            read_checkpoint!(mc, file["simulation"])
        end
    end

    add_sample!(context.measure, :_ll_checkpoint_read_time, checkpoint_read_time)

    return Run(context, mc)
end

function read_checkpoint(
    ::Type{Run{MC,RNG}},
    file_prefix::AbstractString,
    parameters::Dict,
    comm::MPI.Comm,
)::Union{Run{MC,RNG},Nothing} where {MC,RNG}
    no_checkpoint = Ref(false)
    if is_run_leader(comm)
        no_checkpoint[] = !isfile(file_prefix * ".dump.h5")
    end
    MPI.Bcast!(no_checkpoint, 0, comm)

    if no_checkpoint[]
        return nothing
    end

    context = nothing
    mc = MC(parameters)

    if is_run_leader(comm)
        checkpoint_read_time = @elapsed begin
            h5open(file_prefix * ".dump.h5", "r") do file
                context = read_checkpoint(MCContext{RNG}, file["context/0001"])
                for rank = 1:MPI.Comm_size(comm)-1
                    ctx = read_checkpoint(
                        MCContext{RNG},
                        file[@sprintf "context/%04d" rank + 1],
                    )
                    MPI.send(ctx, comm; dest = rank)
                end

                read_checkpoint!(mc, file["simulation"], comm)
            end
        end

        add_sample!(context.measure, :_ll_checkpoint_read_time, checkpoint_read_time)
    else
        context = MPI.recv(comm; source = 0)

        read_checkpoint!(mc, nothing, comm)
    end

    return Run(context, mc)
end
