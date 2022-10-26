import HDF5

abstract type AbstractRNG end

mutable struct MCData{RNG <: AbstractRNG}
    sweeps::Int64
    thermalization_sweeps::Int64

    rng::RNG
    measure::Measurements
    
    function MCData(parameters::Dict)
        measure = Measurements(parameters["binsize"])
        register_observable!(measure, "_ll_checkpoint_read_time", 1, 1)
        register_observable!(measure, "_ll_checkpoint_write_time", 1, 1)

        if haskey(parameters, "seed")
            rng = RNG(data.parameters["seed"])
        else
            rng = RNG()
        end
        
        return new{typeof(rng)}(0, parameters["thermalization"], rng, measure)
    end
end

rand!(data::MCData, X) = rand!(rng = data.rng, X)

is_thermalized(data::MCData) = data.sweeps >= data.thermalization_sweeps

function init!(data::MCData)
    register_observable!(data.measure, "_ll_checkpoint_read_time", 1, 1)
    register_observable!(data.measure, "_ll_checkpoint_write_time", 1, 1)

    if haskey(data.parameters, "seed")
        seed!(data.rng, data.parameters["seed"])
    end

    return nothing
end

function write_measurements!(data::MCData, meas_file::HDF5.Group)
    write_measurements!(data.measure, meas_file["observables"])
    # TODO: write version    

    return nothing
end

function write_checkpoint(data::MCData, check_file::HDF5.Group)
    write_checkpoint(data.rng, check_file["random_number_generator"])
    write_checkpoint(data.measure, check_file["measurements"])

    check_file["thermalization_sweeps"] = minimum(data.sweep, data.thermalization)
    check_file["sweeps"] = data.sweep - mininum(data.sweep, data.thermalization)

    return nothing
end

function read_checkpoint!(data::MCData, check_file::HDF5.Group)
    read_checkpoint!(data.rng, check_file["random_number_generator"])
    read_checkpoint!(data.measure, check_file["measurements"])

    therm_sweeps = check_file["thermalization_sweeps"]
    sweeps = check_file["sweeps"]

    data.sweeps = sweeps + thermalization

    return nothing
end

function write!(data::MCData, mc::AbstractMC, file_prefix::AbstractString)
    checkpoint_write_time = @elapsed begin
        cp(file_prefix * ".meas.h5", file_prefix * ".meas.h5.tmp")
        h5open(file_prefix * ".meas.h5.tmp", "r+") do file
            write_measurements!(data, file)
        end

        h5open(fileprefix * ".dump.h5.tmp", "w") do file
            write_checkpoint(data, file)
            write_checkpoint(mc, file["simulation"])
        end
    end

    add_sample!(data.measure, "__ll_checkpoint_write_time", checkpoint_write_time)

    return nothing
end

function write_finalize(file_prefix::AbstractString)
    mv(file_prefix * ".dump.h5.tmp", file_prefix * ".dump.h5")
    mv(file_prefix * ".meas.h5.tmp", file_prefix * ".meas.h5")

    return nothing
end

function read!(data::MCData, mc::AbstractMC, file_prefix::AbstractString)::Bool
    if isfile(file_prefix * ".dump.h5")
        return false
    end

    checkpoint_read_time = @elapsed begin
        h5open(file_prefix * ".meas.h5.tmp", "r") do file
            read_checkpoint!(data, file)
            read_checkpoint!(mc, file["simulation"])
        end
    end

    add_sample!(data.measure, "__ll_checkpoint_read_time", checkpoint_read_time)
    return true
end
