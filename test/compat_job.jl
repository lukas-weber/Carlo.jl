using Carlo
using Carlo.JobTools

function compat_job(versions; dir)
    return JobInfo(
        "$dir/dump_compat",
        TestMC;
        tasks = [
            TaskInfo(
                "julia$julia_version-$version",
                Dict(
                    :sweeps => 1000,
                    :thermalization => 0,
                    :binsize => 100,
                    :min_julia_version => julia_version,
                ),
            ) for (julia_version, version) in versions
        ],
        checkpoint_time = "00:40",
        run_time = "00:10",
    )
end

function gen_compat_data()
    start(Carlo.SingleScheduler, compat_job([(VERSION, pkgversion(Carlo))]))
end
