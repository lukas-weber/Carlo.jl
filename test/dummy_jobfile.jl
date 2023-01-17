using LoadLeveller
using LoadLeveller.JobTools
include("test_mc.jl")

tm = TaskMaker()
tm.thermalization = 100000
tm.sweeps = 100000000000
tm.binsize = 10

tm.float_type = Float32

task(tm)

job = JobInfo(
    ARGS[1] * "/test",
    TestMC;
    tasks = make_tasks(tm),
    checkpoint_time = "00:05",
    run_time = "00:10",
)

LoadLeveller.start(job, ARGS[2:end])
