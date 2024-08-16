using Carlo
using Carlo.JobTools
using Ising
using MPI

tm = TaskMaker()

tm.sweeps = 200000
tm.thermalization = 2000
tm.binsize = 100

Ts = range(1, 3, 10)
Ls = [100, 200, 300, 500]
for L in Ls
    for T in Ts
        tm.T = T
        tm.Lx = L
        tm.Ly = L
        task(tm)
    end
end

MPI.Init()
cores = MPI.Comm_size(MPI.COMM_WORLD)
job = JobInfo(
    "~/ceph/carlo/bench/$cores",
    Ising.MC;
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    tasks = make_tasks(tm),
)
dur = @elapsed start(job, ARGS)

if MPI.Comm_rank(MPI.COMM_WORLD) == 0 && ARGS == ["run"]
    open("benchmark.dat", "a") do file
        println(file, "$cores, $dur")
    end
end
