using HDF5
using LoadLeveller
import LoadLeveller.JobTools as JT
using MPI

include("test_mc.jl")

job = JT.read_jobinfo_file(ARGS[1])
LoadLeveller.start(LoadLeveller.MPIRunner{TestMC}, job)
