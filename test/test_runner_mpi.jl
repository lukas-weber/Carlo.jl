using HDF5
using LoadLeveller
using MPI

include("test_mc.jl")

job = LoadLeveller.read_jobinfo_file(ARGS[1])
LoadLeveller.start(LoadLeveller.MPIRunner{TestMC}, job)
