# Carlo
[![CI](https://github.com/lukas-weber/Carlo.jl/workflows/CI/badge.svg)](https://github.com/lukas-weber/Carlo.jl/actions)

Carlo is a framework for developing high-performance, distributed (quantum) Monte Carlo simultation.
Its aim is to take care of model-independent tasks such as error analysis, checkpointing and MPI scheduling and leaves the implementation of Monte Carlo updates and estimators to you.


## Getting started

To install the package, type

```julia
using Pkg; Pkg.add("Carlo")
```

The package itself does not include Monte Carlo algorithms. You can test the [Ising](https://github.com/lukas-weber/Ising.jl) or [StochasticSeriesExpansion](https://github.com/lukas-weber/StochasticSeriesExpansion.jl) packages. The former is a particularly easy example you can use as a template for writing your own algorithms.