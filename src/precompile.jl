using PrecompileTools
using ..JobTools

@setup_workload begin
    struct __MC <: AbstractMC end
    __MC(::Any) = __MC()
    Carlo.init!(mc::__MC, ctx::MCContext, params::AbstractDict) = nothing
    Carlo.sweep!(mc::__MC, ctx::MCContext) = nothing
    function Carlo.measure!(mc::__MC, ctx::MCContext)
        measure!(ctx, :test, ctx.sweeps)
        return nothing
    end
    Carlo.write_checkpoint(mc::__MC, out::HDF5.Group) = nothing
    Carlo.read_checkpoint!(mc::__MC, in::HDF5.Group) = nothing

    Carlo.register_evaluables(::Type{__MC}, eval::AbstractEvaluator, params::AbstractDict) =
        nothing
    @compile_workload begin
        tm = TaskMaker()
        tm.thermalization = 1
        tm.sweeps = 1
        tm.binsize = 1

        task(tm)
        task(tm, Lx = 2, T = 1)

        mktempdir() do tmpdir
            job = JobInfo(
                "$tmpdir/test",
                __MC;
                run_time = "00:00",
                checkpoint_time = "1:00",
                tasks = make_tasks(tm),
            )
            JobTools.create_job_directory(job)
            redirect_stdio(stdout = devnull, stderr = devnull) do
                # do *not* call start(SingleScheduler, job): this will lead to deadlocks when precompiling under MPI!
                start(job, ["--help"])
                start(job, ["s"])
                start(job, ["m"])
                start(job, ["d"])
            end
        end
    end
end
