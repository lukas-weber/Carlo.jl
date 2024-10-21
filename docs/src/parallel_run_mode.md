# [Parallel run mode](@id parallel_run_mode)

One of Carlo’s features is to automatically parallelize independent Monte Carlo simulation runs over MPI. These runs can either share the same set of parameters – in which case their results are averaged – or have different parameters entirely.

Sometimes this kind of trivial parallelism is not satisfactory. For example, it does not shorten the time needed for thermalization, and some Monte Carlo algorithms can benefit from some sort of population control that exchanges data between different simulations of the same random process.

For these cases, Carlo features a *parallel run mode* where each Carlo run does not run on one but multiple MPI ranks. Parallel run mode is enabled in [`JobInfo`](@ref) by passing the `ranks_per_run` argument. 

An example for how parallel run mode is used can be found in the implementation of [`ParallelTemperingMC`](@ref).

## Parallel `AbstractMC` interface

In order to use parallel run mode, the Monte Carlo algorithm must implement a modified version of the [`AbstractMC`](@ref) interface including additional `MPI.Comm` arguments that allow coordination between the different ranks per run.

The first three functions

    Carlo.init!(mc::YourMC, ctx::MCContext, params::AbstractDict, comm::MPI.Comm)
    Carlo.sweep!(mc::YourMC, ctx::MCContext, comm::MPI.Comm)
    Carlo.measure!(mc::YourMC, ctx::MCContext, comm::MPI.Comm)

simply receive an additional `comm` argument. An important restriction here is that only rank 0 can make measurements on the given `MCContext`, so you are responsible to communicate the measurement results to that rank.

For checkpointing, there is a similar catch.

    Carlo.write_checkpoint(mc::YourMC, out::Union{HDF5.Group,Nothing}, comm::MPI.Comm)
    Carlo.read_checkpoint!(mc::YourMC, in::Union{HDF5.Group,Nothing}, comm::MPI.Comm)

In these methods, only rank 0 receives an `HDF5.Group` and the other ranks need to communicate. Carlo does not use the collective writing mode of parallel HDF5.

Sometimes, you also want to share work during the construction of `YourMC`. For this reason, Carlo will add the hidden parameter `_comm` to the parameter dictionary received by the constructor `YourMC(params::AbstractDict)`. `params[:_comm]` is then an MPI communicator similar to the `comm` argument of the functions above.

Lastly, the `Carlo.register_evaluables` function remains the same as in the normal interface.
