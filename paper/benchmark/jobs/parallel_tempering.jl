# parallel_tempering.jl

using Carlo
using Carlo.JobTools
using Ising

tm = TaskMaker()

tm.sweeps = 20000
tm.thermalization = 2000
tm.binsize = 100

Ts = range(1.5, 4, 30)

# contract temperatures around Tc for better distribution overlap
Tc = 2.269
Ts += 0.5 .* (Tc .- Ts) ./ (0.6 .+ (Tc .- Ts) .^ 2)


tm.parallel_tempering = (mc = Ising.MC, parameter = :T, values = Ts, interval = 1)

Ls = [32, 64]
for L in Ls
    tm.Lx = L
    tm.Ly = L

    # tm.T is set implicitly by ParallelTemperingMC

    task(tm)
end

job = JobInfo(
    splitext(@__FILE__)[1],
    ParallelTemperingMC; # the underlying model MC is set in tm.parallel_tempering.mc
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    tasks = make_tasks(tm),
    ranks_per_run = length(tm.parallel_tempering.values), # needs to match!
)

start(job, ARGS)
