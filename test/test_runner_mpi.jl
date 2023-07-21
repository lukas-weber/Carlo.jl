using HDF5
using LoadLeveller
using MPI
using Serialization

include("test_mc.jl")

job = deserialize(ARGS[1])
LoadLeveller.start(LoadLeveller.MPIRunner{job.mc}, job)
