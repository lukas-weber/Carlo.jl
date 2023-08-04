# ![Carlo.jl](docs/header.svg)
[![Docs dev](https://img.shields.io/badge/docs-latest-blue.svg)](https://lukas.weber.science/Carlo.jl/dev/)
[![Docs stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://lukas.weber.science/Carlo.jl/stable/)
[![CI](https://github.com/lukas-weber/Carlo.jl/workflows/CI/badge.svg)](https://github.com/lukas-weber/Carlo.jl/actions)
[![codecov](https://codecov.io/gh/lukas-weber/Carlo.jl/branch/main/graph/badge.svg?token=AI8CPOGKXF)](https://codecov.io/gh/lukas-weber/Carlo.jl)

Carlo is a framework for developing high-performance, distributed (quantum) Monte Carlo simultations.
Its aim is to take care of model-independent tasks such as

* autocorrelation and error analysis,
* Monte-Carlo-aware MPI scheduling, and
* checkpointing

while leaving all the flexibility of implementating Monte Carlo updates and estimators to you.


## Getting started

To install the package, type

```julia
using Pkg; Pkg.add("Carlo")
```

The package itself does not include Monte Carlo algorithms. You can test the [Ising](https://github.com/lukas-weber/Ising.jl) or [StochasticSeriesExpansion](https://github.com/lukas-weber/StochasticSeriesExpansion.jl) packages. The former is a particularly easy example you can use as a template for writing your own algorithms.
