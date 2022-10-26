"Your Monte Carlo algorithm type should inherit from this and provide the methods below"
abstract type AbstractMC end

#"Perform one Monte Carlo sweep"
#function sweep!(mc::AbstractMC, data::MCData) end

#"Perform a Monte Carlo measurement"
#function measure!(mc::AbstractMC, data::MCData) end

#function write_checkpoint(mc::AbstractMC, dump_file::HDF5.Group) end
#function read_checkpoint!(mc::AbstractMC, dump_file::HDF5.Group) end

""" This optional function allows you to write custom data to the file system. It provides a `unique_filename` that will not be overwritten by other runs in the simulation."""
function write_output(mc::AbstractMC, unique_filename::AbstractString) end
