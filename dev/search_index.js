var documenterSearchIndex = {"docs":
[{"location":"cli.html#cli","page":"Command line interface","title":"Command line interface","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"    start","category":"page"},{"location":"cli.html#LoadLeveller.start","page":"Command line interface","title":"LoadLeveller.start","text":"start(job::JobInfo, ARGS)\n\nCall this from your job script to start the LoadLeveller command line interface.\n\nIf for any reason you do not want to use job scripts, you can directly schedule a job using\n\nstart(LoadLeveller.MPIRunner{job.mc}, job)\n\n\n\n\n\n","category":"function"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"A job script calling start(job, ARGS) (as shown in Usage) exposes the LoadLeveller command line interface when executed.","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob --help","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"The command line interface allows (re)starting a job, merging preliminary results, and showing the completion status of a calculation.","category":"page"},{"location":"cli.html#Starting-jobs","page":"Command line interface","title":"Starting jobs","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob run","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"This will start a simulation on a single core. To use multiple cores, use MPI.","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"mpirun -n $num_cores ./myjob run","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"Once the simulation is started, a directory myjob.data will be created to store all simulation data. The name of the directory corresponds to the first argument of JobInfo. Usually that will be @__FILE__, but you could collect your simulation data in a different directory.","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"The data directory will contain hdf5 files for each task of the job that contain checkpointing snapshots and measurement results. Once the job is done, LoadLeveller will average the measurement data for you and produce the file myjob.results.json in the same directory as the myjob.data directory. This file contains means and errorbars of all observables. See ResultTools for some tips on consuming this file back into julia for your plotting or other postprocessing.","category":"page"},{"location":"cli.html#Job-status","page":"Command line interface","title":"Job status","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob status","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"Use this command to find out the state of the simulation. It will show a table with the number of completed measurement sweeps, the target number of sweeps, the numbers of runs, and the fraction of them that is thermalized.","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"The fraction is defined as thermalization sweeps completed/total thermalization sweeps needed.","category":"page"},{"location":"cli.html#Merging-jobs","page":"Command line interface","title":"Merging jobs","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob merge","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"Usually LoadLeveller will automatically merge results once a job is complete, but when you are impatient and you want to check on results of a running or aborted job, this command is your friend. It will produce a myjob.results.json file containing the averages of the currently available data.","category":"page"},{"location":"cli.html#Deleting-jobs","page":"Command line interface","title":"Deleting jobs","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob delete","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"This deletes myjob.data and myjob.results.json. Of course, you should archive your simulation data instead of deleting them. However, if you made an error in a previous simulation, keep in mind that by default LoadLeveller will continue it from the checkpoints.","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"For that case of restarting a job there is a handy shortcut as well","category":"page"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"./myjob run --restart","category":"page"},{"location":"cli.html#Shortcuts","page":"Command line interface","title":"Shortcuts","text":"","category":"section"},{"location":"cli.html","page":"Command line interface","title":"Command line interface","text":"All commands here have shortcut versions that you can view in the help.","category":"page"},{"location":"evaluables.html#evaluables","page":"Evaluables","title":"Evaluables","text":"","category":"section"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"In addition to simply calculating the averages of some observables in your Monte Carlo simulations, sometimes you are also interested in quantities that are functions of these observables, such as the Binder cumulant which is related to the ratio of moments of the magnetization.","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"This presents two problems. First, estimating the errors of such quantities is not trivial due to correlations. Second, simply computing functions of quantities with errorbars incurs a bias.","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"Luckily, LoadLeveller can help you with this by letting you define such quantities – we call them evaluables – in the LoadLeveller.register_evaluables(YourMC, eval, params) function.","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"This function gets an Evaluator which can be used to","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"evaluate!","category":"page"},{"location":"evaluables.html#LoadLeveller.evaluate!","page":"Evaluables","title":"LoadLeveller.evaluate!","text":"evaluate!(func::Function, eval::Evaluator, name::Symbol, (ingredients::Symbol...))\n\nDefine an evaluable called name, i.e. a quantity depending on the observable averages ingredients.... The function func will get the ingredients as parameters and should return the value of the evaluable. LoadLeveller will then perform jackknifing to calculate a bias-corrected result with correct error bars that appears together with the observables in the result file.\n\n\n\n\n\n","category":"function"},{"location":"evaluables.html#Example","page":"Evaluables","title":"Example","text":"","category":"section"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"This is an example for a register_evaluables implementation for a model of a magnet.","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"using LoadLeveller\nstruct YourMC <: AbstractMC end # hide\n\nfunction LoadLeveller.register_evaluables(\n    ::Type{YourMC},\n    eval::Evaluator,\n    params::AbstractDict,\n)\n\n    T = params[:T]\n    Lx = params[:Lx]\n    Ly = get(params, :Ly, Lx)\n    \n    evaluate!(eval, :Susceptibility, (:Magnetization2,)) do mag2\n        return Lx * Ly * mag2 / T\n    end\n\n    evaluate!(eval, :BinderRatio, (:Magnetization2, :Magnetization4)) do mag2, mag4\n        return mag2 * mag2 / mag4\n    end\n\n    return nothing\nend","category":"page"},{"location":"evaluables.html","page":"Evaluables","title":"Evaluables","text":"Note that this code is called after the simulation is over, so there is no way to access the simulation state. However, it is possible to get the needed information about the system (e.g. temperature, system size) from the task parameters params.","category":"page"},{"location":"jobtools.html#jobtools","page":"JobTools","title":"JobTools","text":"","category":"section"},{"location":"jobtools.html","page":"JobTools","title":"JobTools","text":"This submodule contains tools to specify or read job information necessary to run LoadLeveller calculations.","category":"page"},{"location":"jobtools.html","page":"JobTools","title":"JobTools","text":"CurrentModule = LoadLeveller.JobTools","category":"page"},{"location":"jobtools.html","page":"JobTools","title":"JobTools","text":"JobInfo\nTaskInfo","category":"page"},{"location":"jobtools.html#LoadLeveller.JobTools.JobInfo","page":"JobTools","title":"LoadLeveller.JobTools.JobInfo","text":"JobInfo(\n    job_directory_prefix::AbstractString,\n    mc::Type;\n    checkpoint_time::Union{AbstractString, Dates.Second},\n    run_time::Union{AbstractString, Dates.Second},\n    tasks::Vector{TaskInfo},\n    ranks_per_run::Integer = 1,\n)\n\nHolds all information required for a Monte Carlo calculation. The data of the calculation (parameters, results, and checkpoints) will be saved under job_directory_prefix.\n\nmc is the the type of the algorithm to use, implementing the abstract_mc interface.\n\ncheckpoint_time and run_time specify the interval between checkpoints and the total desired run_time of the simulation. Both may be specified as a string of format [[hours:]minutes:]seconds\n\nEach job contains a set of tasks, corresponding to different sets of simulation parameters that should be run in parallel. The TaskMaker type can be used to conveniently generate them.\n\nSetting the optional parameter ranks_per_run > 1 enables Parallel run mode.\n\n\n\n\n\n","category":"type"},{"location":"jobtools.html#LoadLeveller.JobTools.TaskInfo","page":"JobTools","title":"LoadLeveller.JobTools.TaskInfo","text":"TaskInfo(name::AbstractString, params::Dict{Symbol,Any})\n\nHolds information of one parameter set in a Monte Carlo calculation. While it is possible to construct it by hand, for multiple tasks, it is recommended to use TaskMaker for convenience.\n\nSpecial parameters\n\nWhile params can hold any kind of parameter, some are special and used to configure the behavior of LoadLeveller.\n\nsweeps: required. The minimum number of Monte Carlo measurement sweeps to perform for the task.\nthermalization: required. The number of thermalization sweeps to perform.\nbinsize: required. The internal default binsize for observables. LoadLeveller will merge this many samples into one bin before saving them.   On top of this, a rebinning analysis is performed, so that this setting mostly affects disk space and IO efficiency. To get correct autocorrelation times, it should be 1. In all other cases much higher.\nrng: optional. Type of the random number generator to use. See rng.\nseed: optional. Optionally run calculations with a fixed seed. Useful for debugging.\nfloat_type: optional. Type of floating point numbers to use for the measurement postprocessing. Default: Float64.\n\nOut of these parameters, it is only permitted to change sweeps for an existing calculation. This is handy to run the simulation for longer or shorter than planned originally.\n\n\n\n\n\n","category":"type"},{"location":"jobtools.html#TaskMaker","page":"JobTools","title":"TaskMaker","text":"","category":"section"},{"location":"jobtools.html","page":"JobTools","title":"JobTools","text":"TaskMaker\ntask\nmake_tasks","category":"page"},{"location":"jobtools.html#LoadLeveller.JobTools.TaskMaker","page":"JobTools","title":"LoadLeveller.JobTools.TaskMaker","text":"TaskMaker()\n\nTool for generating a list of tasks, i.e. parameter sets, to be simulated in a Monte Carlo simulation.\n\nThe fields of TaskMaker can be freely assigned and each time task is called, their current state will be copied into a new task. Finally the list of tasks can be generated using make_tasks\n\nIn most cases the resulting tasks will be used in the constructor of JobInfo, the basic description for jobs in LoadLeveller.\n\nExample\n\nThe following example creates a list of 5 tasks for different parameters T. This could be a scan of the finite-temperature phase diagram of some model. The first task will be run with more sweeps than the rest.\n\ntm = TaskMaker()\ntm.sweeps = 10000\ntm.thermalization = 2000\ntm.binsize = 500\n\ntask(tm; T=0.04)\ntm.sweeps = 5000\nfor T in range(0.1, 10, length=5)\n    task(tm; T=T)\nend\n\ntasks = make_tasks(tm)\n\n\n\n\n\n","category":"type"},{"location":"jobtools.html#LoadLeveller.JobTools.task","page":"JobTools","title":"LoadLeveller.JobTools.task","text":"task(tm::TaskMaker; kwargs...)\n\nCreates a new task for the current set of parameters saved in tm. Optionally, kwargs can be used to specify parameters that are set for this task only.\n\n\n\n\n\n","category":"function"},{"location":"jobtools.html#LoadLeveller.JobTools.make_tasks","page":"JobTools","title":"LoadLeveller.JobTools.make_tasks","text":"make_tasks(tm::TaskMaker)::Vector{TaskInfo}\n\nGenerate a list of tasks from tm based on the previous calls of task. The output of this will typically be supplied to the tasks argument of JobInfo.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#abstract_mc","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"","category":"section"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"To run your own Monte Carlo algorithm with LoadLeveller, you need to implement the AbstractMC interface documented in this file. For an example implementation showcasing all the features, take a look at the Ising example implementation.","category":"page"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"LoadLeveller.AbstractMC","category":"page"},{"location":"abstract_mc.html#LoadLeveller.AbstractMC","page":"Implementing your algorithm","title":"LoadLeveller.AbstractMC","text":"This type is an interface for implementing your own Monte Carlo algorithm that will be run by LoadLeveller.\n\n\n\n\n\n","category":"type"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"The following methods all need to be defined for your Monte Carlo algoritm type (here referred to as YourMC <: AbstractMC).","category":"page"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"LoadLeveller.init!\nLoadLeveller.sweep!\nLoadLeveller.measure!(::AbstractMC, ::MCContext)\nLoadLeveller.write_checkpoint\nLoadLeveller.read_checkpoint!\nLoadLeveller.register_evaluables","category":"page"},{"location":"abstract_mc.html#LoadLeveller.init!","page":"Implementing your algorithm","title":"LoadLeveller.init!","text":"init!(mc::YourMC, ctx::MCContext, params::AbstractDict [, comm::MPI.Comm])\n\nExecuted when a simulation is started from scratch.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#LoadLeveller.sweep!","page":"Implementing your algorithm","title":"LoadLeveller.sweep!","text":"sweep!(mc::YourMC, ctx::MCContext [, comm::MPI.Comm])\n\nPerform one Monte Carlo sweep or update to the configuration.\n\nDoing measurements is supported during this step as some algorithms require doing so for efficiency. However you are responsible for checking if the simulation is_thermalized.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#LoadLeveller.measure!-Tuple{AbstractMC, MCContext}","page":"Implementing your algorithm","title":"LoadLeveller.measure!","text":"measure!(mc::YourMC, ctx::MCContext [, comm::MPI.comm])\n\nPerform one Monte Carlo measurement.\n\n\n\n\n\n","category":"method"},{"location":"abstract_mc.html#LoadLeveller.write_checkpoint","page":"Implementing your algorithm","title":"LoadLeveller.write_checkpoint","text":"write_checkpoint(mc::YourMC, out::HDF5.Group [, comm::MPI.comm])\n\nSave the complete state of the simulation to out.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#LoadLeveller.read_checkpoint!","page":"Implementing your algorithm","title":"LoadLeveller.read_checkpoint!","text":"read_checkpoint!(mc::YourMC, in::HDF5.Group [, comm::MPI.comm])\n\nRead the state of the simulation from in.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#LoadLeveller.register_evaluables","page":"Implementing your algorithm","title":"LoadLeveller.register_evaluables","text":"register_evaluables(mc::Type{YourMC}, eval::Evaluator, params::AbstractDict)\n\nThis function is used to calculate postprocessed quantities from quantities that were measured during the simulation. Common examples are variances or ratios of observables.\n\nSee evaluables for more details.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#mc_context","page":"Implementing your algorithm","title":"Interfacing with LoadLeveller features","text":"","category":"section"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"The MCContext type, passed to your code by some of the functions above enables to use some features provided by LoadLeveller.","category":"page"},{"location":"abstract_mc.html","page":"Implementing your algorithm","title":"Implementing your algorithm","text":"MCContext\nis_thermalized\nmeasure!(::MCContext, ::Symbol, ::Any)","category":"page"},{"location":"abstract_mc.html#LoadLeveller.MCContext","page":"Implementing your algorithm","title":"LoadLeveller.MCContext","text":"Holds the LoadLeveller-internal state of the simulation and provides an interface to\n\nRandom numbers: the public field MCContext.rng is a random number generator (see rng)\nMeasurements: see measure!(::MCContext, ::Symbol, ::Any)\nSimulation state: see is_thermalized\n\n\n\n\n\n","category":"type"},{"location":"abstract_mc.html#LoadLeveller.is_thermalized","page":"Implementing your algorithm","title":"LoadLeveller.is_thermalized","text":"is_thermalized(ctx::MCContext)::Bool\n\nReturns true if the simulation is thermalized.\n\n\n\n\n\n","category":"function"},{"location":"abstract_mc.html#LoadLeveller.measure!-Tuple{MCContext, Symbol, Any}","page":"Implementing your algorithm","title":"LoadLeveller.measure!","text":"measure!(ctx::MCContext, name::Symbol, value)\n\nMeasure a sample for the observable named name. The sample value may be either a scalar or vector of a float type. \n\n\n\n\n\n","category":"method"},{"location":"resulttools.html#result_tools","page":"ResultTools","title":"ResultTools","text":"","category":"section"},{"location":"resulttools.html","page":"ResultTools","title":"ResultTools","text":"This is a small module to ease importing LoadLeveller results back into Julia. It contains the function","category":"page"},{"location":"resulttools.html","page":"ResultTools","title":"ResultTools","text":"LoadLeveller.ResultTools.dataframe","category":"page"},{"location":"resulttools.html#LoadLeveller.ResultTools.dataframe","page":"ResultTools","title":"LoadLeveller.ResultTools.dataframe","text":"ResultTools.dataframe(result_json::AbstractString)\n\nHelper to import result data from a *.results.json file produced after a LoadLeveller calculation. Returns a Tables.jl-compatible dictionary that can be used as is or converted into a DataFrame or other table structure. Observables and their errorbars will be converted to Measurements.jl measurements.\n\n\n\n\n\n","category":"function"},{"location":"resulttools.html","page":"ResultTools","title":"ResultTools","text":"An example of using ResultTools with DataFrames.jl would be the following.","category":"page"},{"location":"resulttools.html","page":"ResultTools","title":"ResultTools","text":"using Plots\nusing DataFrames\nusing LoadLeveller.ResultTools\n\ndf = DataFrame(ResultTools.dataframe(\"example.results.json\"))\n\nplot(df.T, df.Energy)","category":"page"},{"location":"index.html#LoadLeveller.jl","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"","category":"section"},{"location":"index.html#Overview","page":"LoadLeveller.jl","title":"Overview","text":"","category":"section"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"LoadLeveller is a framework that aims to simplify the implementation of high-performance Monte Carlo codes by handling the parallelization, checkpointing and error analysis. What sets it apart is a focus on ease of use and minimalism.","category":"page"},{"location":"index.html#Installation","page":"LoadLeveller.jl","title":"Installation","text":"","category":"section"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"using Pkg\nPkg.add(\"LoadLeveller\")","category":"page"},{"location":"index.html#Usage","page":"LoadLeveller.jl","title":"Usage","text":"","category":"section"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"In order to work with LoadLeveller, a Monte Carlo algorithm has to implement the AbstractMC interface. A full example of this is given in the reference implementation for the Ising model.","category":"page"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"Then, to perform simulation, one writes a job script defining all the parameters needed for the simulation, which could look something like the following.","category":"page"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"#!/usr/bin/env julia\n\nusing LoadLeveller\nusing LoadLeveller.JobTools\nusing Ising\n\ntm = TaskMaker()\ntm.sweeps = 10000\ntm.thermalization = 2000\ntm.binsize = 100\n\ntm.Lx = 10\ntm.Ly = 10\n\nTs = range(0.1, 4, length=20)\nfor T in Ts\n    task(tm; T=T)\nend\n\njob = JobInfo(@__FILE__, Ising.MC;\n    checkpoint_time=\"30:00\",\n    run_time=\"15:00\",\n    tasks=make_tasks(tm)\n)\n\nstart(dummy, dummy2) = nothing # hide\nstart(job, ARGS)","category":"page"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"This example starts a simulation for the Ising model on the 10×10 lattice for 20 different temperatures. Using the function start(job::JobInfo, ARGS) enables the LoadLeveller CLI.","category":"page"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"The first argument of JobInfo is the prefix for starting the simulation. One possible convention is to use the @__FILE__ macro to automatically start jobs in the same directory as the script file. Alternatively, the script file could be located in a git repository, while the large simulation directory is located elsewhere.","category":"page"},{"location":"index.html","page":"LoadLeveller.jl","title":"LoadLeveller.jl","text":"It should be noted that in contrast to some other packages, the parameter files of LoadLeveller are programs. This is especially handy when a calculation consists of many different tasks.","category":"page"},{"location":"rng.html#rng","page":"Random Number Generators","title":"Random Number Generators","text":"","category":"section"},{"location":"rng.html","page":"Random Number Generators","title":"Random Number Generators","text":"LoadLeveller takes care of storing and managing the state of random number generators (RNG) for you. It is accessible through the rng field of MCContext and the type of RNG to use can be set by the rng parameter in every task (see TaskInfo).","category":"page"},{"location":"rng.html","page":"Random Number Generators","title":"Random Number Generators","text":"The currently supported types are","category":"page"},{"location":"rng.html","page":"Random Number Generators","title":"Random Number Generators","text":"Random.Xoshiro","category":"page"}]
}