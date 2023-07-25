# Carlo.jl

## Overview

Carlo is a framework that aims to simplify the implementation of high-performance Monte Carlo codes
by handling the parallelization, checkpointing and error analysis. What sets it apart is a focus on
ease of use and minimalism.

## Installation

```@repl
using Pkg
Pkg.add("Carlo")
```

## Usage

In order to work with Carlo, a Monte Carlo algorithm has to implement the [AbstractMC](@ref abstract_mc) interface. A full example of this is given in the
reference implementation for the [Ising](https://github.com/lukas-weber/Ising.jl) model.

Then, to perform simulation, one writes a *job script* defining all the parameters needed for the simulation, which could look something like the following.
```@example
#!/usr/bin/env julia

using Carlo
using Carlo.JobTools
using Ising

tm = TaskMaker()
tm.sweeps = 10000
tm.thermalization = 2000
tm.binsize = 100

tm.Lx = 10
tm.Ly = 10

Ts = range(0.1, 4, length=20)
for T in Ts
    task(tm; T=T)
end

job = JobInfo(@__FILE__, Ising.MC;
    checkpoint_time="30:00",
    run_time="15:00",
    tasks=make_tasks(tm)
)

start(dummy, dummy2) = nothing # hide
start(job, ARGS)
```

This example starts a simulation for the Ising model on the 10×10 lattice for 20 different temperatures. Using the function [`start(job::JobInfo, ARGS)`](@ref) enables the [Carlo CLI](@ref cli).

The first argument of JobInfo is the prefix for starting the simulation. One possible convention is to use the `@__FILE__` macro to automatically start jobs in the same directory as the script file. Alternatively,
the script file could be located in a git repository, while the large simulation directory is located elsewhere.

It should be noted that in contrast to some other packages, the parameter files of Carlo are programs. This is especially handy when a calculation consists of many different tasks.
