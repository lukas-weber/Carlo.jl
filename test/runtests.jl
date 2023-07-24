using Test
using LoadLeveller
using LoadLeveller.JobTools
import LoadLeveller.JobTools as JT
using MPI

include("test_utils.jl")
include("test_mc.jl")

tests = [
    "test_taskinfo.jl"
    "test_jobinfo.jl"
    "test_evaluable.jl"
    "test_scheduler.jl"
    "test_run.jl"
    "test_observable.jl"
    "test_random_wrap.jl"
    "test_results.jl"
    "test_measurements.jl"
    "test_mccontext.jl"
    "test_merge.jl"
    "test_taskmaker.jl"
    "test_cli.jl"
]

for test in tests
    include(test)
end
