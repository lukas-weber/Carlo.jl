using PrecompileTools
using ..JobTools

@setup_workload begin
    include("../test/test_mc.jl")
    @compile_workload begin

        tm = TaskMaker()
        tm.thermalization = 10000
        tm.sweeps = 10000
        tm.binsize = 1

        Lxs = [10, 20]
        Ts = range(1, 4, length=10)

        tm.test = [1, 2, 3, 4]

        for Lx in Lxs
            for T in Ts
                task(tm, Lx=Lx, T=T)
            end
        end
        mktempdir() do dir

        job = JobInfo(
            dir * "/precompile_test",
            TestMC;
            tasks = make_tasks(tm),
            checkpoint_time = "30:00",
            run_time = "24:00:00"
        )

            redirect_stderr(devnull) do
                start(job, ["run", "-s"])
                start(job, ["run"])
                start(job, ["status"])
                start(job, ["merge"])
                start(job, ["delete"])
            end
        end
    end
end
