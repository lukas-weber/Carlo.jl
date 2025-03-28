module JobTools
export JobInfo,
    TaskInfo,
    TaskMaker,
    task,
    make_tasks,
    result_filename,
    current_task_name,
    run_time_from_slurm

using Statistics

include("taskinfo.jl")
include("jobinfo.jl")
include("taskmaker.jl")

end
