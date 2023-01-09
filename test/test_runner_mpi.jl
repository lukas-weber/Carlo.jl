using HDF5
using LoadLeveller
import LoadLeveller.JobTools as JT
using MPI
using Serialization

include("test_mc.jl")

job = deserialize(ARGS[1])
LoadLeveller.start(LoadLeveller.MPIRunner{TestMC}, job)
