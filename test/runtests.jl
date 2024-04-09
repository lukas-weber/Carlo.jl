using Test
using Carlo
using Carlo.JobTools
import Carlo.JobTools as JT
using Carlo.ResultTools
using MPI

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
    "test_cli.jl"
]

for test in tests
    include(test)
end
