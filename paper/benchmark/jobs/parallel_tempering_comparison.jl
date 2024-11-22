# example_job.jl

using Carlo
using Carlo.JobTools
using Ising

tm = TaskMaker()

tm.sweeps = 20000
tm.thermalization = 2000
tm.binsize = 100

Ts = range(1.5, 4, 30)
Tc = 2.269
Ts += 0.5 .* (Tc .- Ts) ./ (0.6 .+ (Tc .- Ts) .^ 2)

Ls = [4, 64]

for L in Ls
    for T in Ts
        tm.T = T
        tm.Lx = L
        tm.Ly = L
        task(tm)
    end
end

job = JobInfo(
    splitext(@__FILE__)[1],
    Ising.MC;
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    tasks = make_tasks(tm),
)

start(job, ARGS)
