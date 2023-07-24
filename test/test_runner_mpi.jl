using HDF5
using LoadLeveller
using MPI
using Serialization
using Logging

include("test_mc.jl")

job = deserialize(ARGS[1])
with_logger(Logging.NullLogger()) do
    LoadLeveller.start(LoadLeveller.MPIRunner, job)
end
