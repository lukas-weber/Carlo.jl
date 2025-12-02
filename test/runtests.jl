import Carlo.JobTools as JT
using Carlo
using Carlo.JobTools
using Carlo.ResultTools
using Dates
using HDF5
using JSON
using Logging
using MPI
using Measurements
using Random
using Serialization
using Statistics
using StructEquality
using LinearAlgebra
using Test

include("test_utils.jl")
include("test_mc.jl")

tests = [
    "test_dump_compat.jl"
    "test_taskinfo.jl"
    "test_jobinfo.jl"
    "test_evaluable.jl"
    "test_run.jl"
    "test_accumulator.jl"
    "test_random_wrap.jl"
    "test_results.jl"
    "test_measurements.jl"
    "test_mccontext.jl"
    "test_merge.jl"
    "test_taskmaker.jl"
    "test_scheduler.jl"
    "test_parallel_tempering.jl"
    "test_cli.jl"
]

for test in tests
    include(test)
end
