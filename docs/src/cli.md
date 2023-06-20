# [Command line interface](@id cli)

```@docs
    start
```
A job script calling `start(job, ARGS)` (as shown in [Usage](@ref)) exposes the LoadLeveller command line interface when executed.

```bash
./myjob --help
```

The command line interface allows (re)starting a job, merging preliminary results, and showing the completion status of a calculation.

## Starting jobs

```bash
./myjob run
```

This will start a simulation on a single core. To use multiple cores, use MPI.

```bash
mpirun -n $num_cores ./myjob run
```

Once the simulation is started, a directory `myjob.data` will be created to store all simulation data. The name of the directory corresponds to the first argument of `JobInfo`. Usually that will be `@__FILE__`, but you could collect your simulation data in a different directory.

The data directory will contain hdf5 files for each task of the job that contain checkpointing snapshots and measurement results. Once the job is done, LoadLeveller will average the measurement data for you and produce the file `myjob.results.json` in the same directory as the `myjob.data` directory. This file contains means and errorbars of all observables. See [ResultTools](@ref result_tools) for some tips on consuming this file back into julia for your plotting or other postprocessing.

## Job status

```bash
./myjob status
```

Use this command to find out the state of the simulation. It will show a table with the number of completed measurement sweeps, the target number of sweeps, the numbers of runs, and the fraction of them that is thermalized.

The fraction is defined as thermalization sweeps completed/total thermalization sweeps needed.

## Merging jobs

```bash
./myjob merge
```

Usually LoadLeveller will automatically merge results once a job is complete, but when you are impatient and you want to check on results of a running or aborted job, this command is your friend. It will produce a `myjob.results.json` file containing the averages of the currently available data.

## Deleting jobs

```bash
./myjob delete
```

This deletes `myjob.data` and `myjob.results.json`. Of course, you should archive your simulation data instead of deleting them. However, if you made an error in a previous simulation, keep in mind that by default LoadLeveller will continue it from the checkpoints.

For that case of restarting a job there is a handy shortcut as well

```bash
./myjob run --restart
```

## Shortcuts

All commands here have shortcut versions that you can view in the help.