using Test
include("test_utils.jl")

tests = [
    "test_mc.jl"
    "test_walker.jl"
    "test_observable.jl"
    "test_random_wrap.jl"
    "test_results.jl"
    "test_evaluable.jl"
    "test_measurements.jl"
    "test_mccontext.jl"
    "test_merge.jl"
    "test_runner.jl"
]

for test in tests
    include(test)
end
