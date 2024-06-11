# Carlo.jl

## Overview

Carlo is a framework that aims to simplify the implementation of high-performance Monte Carlo codes
by handling the parallelization, checkpointing and error analysis. What sets it apart is a focus on
ease of use and minimalism.

## Installation
Installation is simple via the Julia REPL.
```julia
] add Carlo
```

If you wish to use the system MPI implementation, take a look at the [MPI.jl documentation](https://juliaparallel.org/MPI.jl/stable/configuration/#using_system_mpi) and be aware that in that case also the system binary of HDF5 as described [here](https://juliaio.github.io/HDF5.jl/stable/#Using-custom-or-system-provided-HDF5-binaries)!
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

This example starts a simulation for the Ising model on the 10×10 lattice for 20 different temperatures. Using the function [`start(job::JobInfo, ARGS)`](@ref) enables the Carlo CLI when we  execute the script above as follows.

```bash
./myjob --help
```

The command line interface allows (re)starting a job, merging preliminary results, and showing the completion status of a calculation.

### Starting jobs

```bash
./myjob run
```

This will start a simulation on a single core. To use multiple cores, use MPI.

```bash
mpirun -n $num_cores ./myjob run
```

Once the simulation is started, a directory `myjob.data` will be created to store all simulation data. The name of the directory corresponds to the first argument of `JobInfo`. Usually that will be `@__FILE__`, but you could also collect your simulation data in a different directory.

The data directory will contain hdf5 files for each task of the job that contain checkpointing snapshots and measurement results. Once the job is done, Carlo will average the measurement data for you and produce the file `myjob.results.json` in the same directory as the `myjob.data` directory. This file contains means and errorbars of all observables. See [ResultTools](@ref result_tools) for some tips on consuming this file back into julia for your plotting or other postprocessing.

### Job status

```bash
./myjob status
```

Use this command to find out the state of the simulation. It will show a table with the number of completed measurement sweeps, the target number of sweeps, the numbers of runs, and the fraction of them that is thermalized.

The fraction is defined as thermalization sweeps completed/total thermalization sweeps needed.

### Merging jobs

```bash
./myjob merge
```

Usually Carlo will automatically merge results once a job is complete, but when you are impatient and you want to check on results of a running or aborted job, this command is your friend. It will produce a `myjob.results.json` file containing the averages of the currently available data.

### Deleting jobs

```bash
./myjob delete
```

This deletes `myjob.data` and `myjob.results.json`. Of course, you should archive your simulation data instead of deleting them. However, if you made an error in a previous simulation, keep in mind that by default Carlo will continue it from the checkpoints.

For that case of restarting a job there is a handy shortcut as well

```bash
./myjob run --restart
```

## Shortcuts

All commands here have shortcut versions that you can view in the help.
