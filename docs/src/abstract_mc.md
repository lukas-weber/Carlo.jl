# [Implementing your algorithm](@id abstract_mc)

To run your own Monte Carlo algorithm with Carlo, you need to implement the `AbstractMC` interface documented in this file.
For an example implementation showcasing all the features, take a look at the [Ising](https://github.com/lukas-weber/Ising.jl) example
implementation.

```@docs
Carlo.AbstractMC
```

The following methods all need to be defined for your Monte Carlo algoritm type (here referred to as `YourMC <: AbstractMC`). See [Parallel run mode](@ref parallel_run_mode) for a slightly different interface that allows inner MPI parallelization of your algorithm.

```@docs
Carlo.init!
Carlo.sweep!
Carlo.measure!(::AbstractMC, ::MCContext)
Carlo.write_checkpoint
Carlo.read_checkpoint!
Carlo.register_evaluables
```

# [Interfacing with Carlo features](@id mc_context)
The `MCContext` type, passed to your code by some of the functions above enables to use some features provided by Carlo.
```@docs
MCContext
is_thermalized
measure!(::MCContext, ::Symbol, ::Any)
```
