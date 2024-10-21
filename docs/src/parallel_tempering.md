# [Parallel tempering](@id parallel_tempering)

[Parallel tempering](https://en.wikipedia.org/wiki/Parallel_tempering) is a method to improve the statistics and ergodicity of a Markov-chain Monte Carlo simulation by running multiple copies with different parameters in parallel and allowing updates that exchange Monte Carlo configurations between the different parameters. A classical example would be to simulate a glassy model at different temperatures so that decorrelated high-temperature configurations continuously enter the low-temperature region and sample the glassy configuration space efficiently.

Carlo.jl provides an implementation of parallel tempering through a “meta” implementation of the `AbstractMC` interface, `ParallelTemperingMC`. It is a Monte Carlo algorithm that can run any other `AbstractMC` implementation with parallel tempering.

```@docs
ParallelTemperingMC
```

In order to work with parallel tempering, the child algorithm only has to implement the following two methods.
```@docs
Carlo.parallel_tempering_log_weight_ratio
Carlo.parallel_tempering_change_parameter!
```

The algorithm works by orchestrating a number of Monte Carlo processes along a chain of parameter values. Alternatingly, all adjacent even and odd pairs compare their configuration weights and propose a switch of their configurations. If the switch is accepted, the Monte Carlo processes exchange their positions on the chain.

## Configuration

When running a simulation, `ParallelTemperingMC` is configured through the `parallel_tempering` task parameter

```@example
using Carlo
using Carlo.JobTools
struct YourMC <: AbstractMC end # hide

num_steps = 10

tm = TaskMaker()

tm.parallel_tempering = (
    mc = YourMC,
    parameter = :T,
    values = range(1, 2, num_steps),
    interval = 20,
)

tm.sweeps = 10000
tm.thermalization = 1000
tm.binsize = 100
# [set other parameters here]

task(tm)

job = JobInfo(
    "my_job",
    ParallelTemperingMC;
    checkpoint_time = "45:00",
    run_time = "24:00:00",
    tasks = make_tasks(tm),
    ranks_per_run = num_steps,
)
```

Here, `mc` is the type of the child Monte Carlo algorithm that should be run with parallel tempering. `parameter` is the name of the parameter that should be exchanged in the parallel tempering and `values` is a chain of values along which exchanges take place. Care should be taken that the probability distributions for adjacent values have some overlap. `interval` sets the number of Monte Carlo sweeps between a tempering update. A single task set up like that will simulate the entire chain of parameter values at once. It is also possible to simulate multiple independent chains by creating multiple tasks.

In `JobInfo` your Monte Carlo type is then replaced by `ParallelTemperingMC`. Under the hood, `ParallelTemperingMC` runs in [parallel run mode](@ref parallel_run_mode) and `ranks_per_run` has to be set to the number of parameters in the tempering chain. The simulation then has to be run with MPI and the appropriate number of ranks, `n * ranks_per_run + 1`.

!!! note
    At the moment, the child Monte Carlo algorithm can only run in single run mode. However, lifting this limitation should not be too hard. If you intend to run parallel tempering on a parallel run mode code, open an issue on GitHub.

## Results

Each observable and evaluable that is calculated by the child code is stacked into a vector where each entry corresponds to a parameter value in the parallel tempering chain. For example, if the child code in the above example calculates the energy, the output for it will be a vector with `num_steps` values corresponding to the different temperatures in `tm.parallel_tempering.values`. Observables which are already vectors or higher order arrays in the child code will gain a new last dimension which corresponds to the parallel tempering parameter.

Additionally, the observable `ParallelTemperingPermutation` records the permutation of configurations on the parallel tempering chain. This can be used to gauge the ergodicity of the parallel tempering updates.

Another self-contained example of parallel tempering is contained in the [`Ising`](https://github.com/lukas-weber/Ising.jl) reference implementation.
