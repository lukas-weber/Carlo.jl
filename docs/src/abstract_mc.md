# [Implementing your algorithm](@id abstract_mc)

To run your own Monte Carlo algorithm with LoadLeveller, you need to implement the `AbstractMC` interface documented in this file.
For an example implementation showcasing all the features, take a look at the [Ising](https://github.com/lukas-weber/Ising.jl) example
implementation.

```@docs
LoadLeveller.AbstractMC
```

The following methods all need to be defined for your Monte Carlo algoritm type (here referred to as `YourMC <: AbstractMC`).

```@docs
LoadLeveller.init!
LoadLeveller.sweep!
LoadLeveller.measure!(::AbstractMC, ::MCContext)
LoadLeveller.write_checkpoint
LoadLeveller.read_checkpoint!
LoadLeveller.register_evaluables
```

# [Interfacing with LoadLeveller features](@id mc_context)
The `MCContext` type, passed to your code by some of the functions above enables to use some features provided by LoadLeveller.
```@docs
MCContext
is_thermalized
measure!(::MCContext, ::Symbol, ::Any)
```
