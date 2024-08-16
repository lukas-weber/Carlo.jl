
using Carlo
using Carlo.JobTools
using Ising
using MPI

tm = TaskMaker()

tm.sweeps = 20000
tm.thermalization = 4000
tm.binsize = 1

tm.Lx = 20
tm.Ly = 20
tm.T = 2.3

for i = 1:9000
    tm.id = i
    task(tm)
end

MPI.Init()
cores = MPI.Comm_size(MPI.COMM_WORLD)
job = JobInfo(
    "~/ceph/carlo/error_bench",
    Ising.MC;
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    tasks = make_tasks(tm),
)
start(job, ARGS)
