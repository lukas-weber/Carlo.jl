using Random
using Printf

struct Run{MC<:AbstractMC,RNG<:Random.AbstractRNG}
    context::MCContext{RNG}
    implementation::MC
end

function Run{MC,RNG}(params::Dict, comm::MPI.Comm) where {MC<:AbstractMC,RNG<:AbstractRNG}
    seed_variation = MPI.Comm_rank(comm)
    context = MCContext{RNG}(params; seed_variation)
    implementation = MC(merge(params, Dict(:_comm => comm)))
    init!(implementation, context, params, comm)

    return Run{MC,RNG}(context, implementation)
end

"""Perform one MC step. Returns the number of thermalized sweeps performed"""
function step!(run::Run, comm::MPI.Comm)
    sweep_time = @elapsed sweep!(run.implementation, run.context, comm)
    run.context.sweeps += 1
    if is_thermalized(run.context)
        measure_time = @elapsed measure!(run.implementation, run.context, comm)

        if MPI.Comm_rank(comm) == 0
            measure!(run.context, :_ll_sweep_time, sweep_time)
            measure!(run.context, :_ll_measure_time, measure_time)
        end

        return 1
    end

    if MPI.Comm_rank(comm) != 0
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

function write_checkpoint!(run::Run, file_prefix::AbstractString, comm::MPI.Comm)
    checkpoint_write_time = @elapsed begin
        is_run_leader = MPI.Comm_rank(comm) == 0
        if is_run_leader
            write_measurements(run, file_prefix)
        elseif !isempty(run.context.measure)
            error("In parallel run mode, only the first rank of a run can do measurements!")
        end

        contexts = MPI.gather(run.context, comm)
        if !is_run_leader
            write_checkpoint(run.implementation, nothing, comm)
        else
            h5open(file_prefix * ".dump.h5.tmp", "w") do file
                for (i, context) in enumerate(contexts)
                    write_checkpoint(context, create_group(file, @sprintf("context/%04d", i)))
                end

                write_checkpoint(run.implementation, create_group(file, "simulation"), comm)
                write_hdf5(
                    Version(typeof(run.implementation)),
                    create_group(file, "version"),
                )
            end
        end
    end

    if is_run_leader
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
    mc = MC(merge(parameters, Dict(:_comm => comm)))

    if is_run_leader(comm)
        checkpoint_read_time = @elapsed begin
            h5open(file_prefix * ".dump.h5", "r") do file
                ranks = 0:MPI.Comm_size(comm)-1
                keys = [@sprintf("context/%04d", rank + 1) for rank in ranks]

                contexts = [
                    haskey(file, key) ? read_checkpoint(MCContext{RNG}, file[key]) :
                    MCContext{RNG}(parameters; seed_variation = rank) for
                    (rank, key) in zip(ranks, keys)
                ]
                context = MPI.scatter(contexts, comm)

                read_checkpoint!(mc, file["simulation"], comm)
            end
        end
        @assert context !== nothing

        add_sample!(context.measure, :_ll_checkpoint_read_time, checkpoint_read_time)
    else
        context = MPI.scatter(nothing, comm)

        read_checkpoint!(mc, nothing, comm)
    end

    @assert context !== nothing

    return Run{MC,RNG}(context, mc)
end
