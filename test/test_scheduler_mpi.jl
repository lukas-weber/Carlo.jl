using HDF5
using Carlo
using MPI
using Serialization
using Logging

include("test_mc.jl")

job, scheduler = deserialize(ARGS[1])
# with_logger(Logging.NullLogger()) do
Carlo.start(scheduler, job)
# end
