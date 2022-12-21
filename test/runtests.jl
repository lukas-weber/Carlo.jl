using Test
include("test_utils.jl")

tests = [
    "test_observable.jl"
]

for test in tests
    include(test)
end
