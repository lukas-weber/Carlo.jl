using MPI

"""
This type is an interface for implementing your own Monte Carlo algorithm that will be run by Carlo.
"""
abstract type AbstractMC end

"""
    Carlo.init!(mc::YourMC, ctx::MCContext, params::AbstractDict)

Executed when a simulation is started from scratch.
"""
function init! end
init!(mc::AbstractMC, ctx::MCContext, params::AbstractDict, comm::MPI.Comm) =
    init!(mc, ctx, params)

"""
    Carlo.sweep!(mc::YourMC, ctx::MCContext)

Perform one Monte Carlo sweep or update to the configuration.

!!! note
    Doing measurements is supported during this step as some algorithms require doing so for efficiency. Remember to check for [`is_thermalized`](@ref) in that case.
"""
function sweep! end
sweep!(mc::AbstractMC, ctx::MCContext, comm::MPI.Comm) = sweep!(mc, ctx)

"""
    Carlo.measure!(mc::YourMC, ctx::MCContext)

Perform one Monte Carlo measurement.
"""
function measure! end
function measure!(mc::AbstractMC, ctx::MCContext, comm::MPI.Comm)
    if comm == MPI.COMM_NULL || MPI.Comm_size(comm) == 1
        measure!(mc, ctx)
    else
        error(
            "running in parallel run mode but measure(::MC, ::MCContext, ::MPI.Comm) not implemented",
        )
    end
    return nothing
end

"""
    Carlo.write_checkpoint(mc::YourMC, out::HDF5.Group)

Save the complete state of the simulation to `out`.
"""
function write_checkpoint end
function write_checkpoint(
    mc::AbstractMC,
    dump_file::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    if comm == MPI.COMM_NULL || MPI.Comm_size(comm) == 1
        write_checkpoint(mc, dump_file)
    else
        error(
            "running in parallel run mode but write_checkpoint(::MC, ::Union{HDF5.Group,Nothing}, ::MPI.Comm) not implemented",
        )
    end
    return nothing
end


function write_checkpoint(
    x::Union{AbstractArray,Number},
    out::HDF5.Group,
    name::AbstractString = "value",
)
    write(out, name, x)
end
function read_checkpoint(
    ::Type{T},
    in::HDF5.Group,
    name::AbstractString = "value",
) where {T<:Union{AbstractArray,Number}}
    return read(in, name)
end



"""
    Carlo.read_checkpoint!(mc::YourMC, in::HDF5.Group)

Read the state of the simulation from `in`.
"""
function read_checkpoint! end
function read_checkpoint!(
    mc::AbstractMC,
    dump_file::Union{HDF5.Group,Nothing},
    comm::MPI.Comm,
)
    if comm == MPI.COMM_NULL || MPI.Comm_size(comm) == 1
        read_checkpoint!(mc, dump_file)
    else
        error(
            "running in parallel run mode but read_checkpoint!(::MC, ::Union{HDF5.Group,Nothing}, ::MPI.Comm) not implemented",
        )
    end
    return nothing
end

"""
    Carlo.register_evaluables(mc::Type{YourMC}, eval::Evaluator, params::AbstractDict)

This function is used to calculate postprocessed quantities from quantities that were measured during the simulation. Common examples are variances or ratios of observables.

See [evaluables](@ref) for more details.
"""
function register_evaluables end
