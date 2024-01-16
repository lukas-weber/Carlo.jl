using PrecompileTools
using ..JobTools

@setup_workload begin
    include("../test/test_mc.jl")
    @compile_workload begin
        tm = TaskMaker()
        tm.thermalization = 10
        tm.sweeps = 10
        tm.binsize = 1
        tm.test = [1]

        task(tm, Lx = 2, T = 1)
        mktempdir() do dir

            job = JobInfo(
                dir * "/precompile_test",
                TestMC;
                tasks = make_tasks(tm),
                checkpoint_time = "30:00",
                run_time = "24:00:00",
            )

            redirect_stdio(stdout = devnull, stderr = devnull) do
                start(job, ["run", "-s"])
                # start(job, ["run"])
                start(job, ["status"])
                start(job, ["merge"])
                start(job, ["delete"])
            end
        end
    end
end
