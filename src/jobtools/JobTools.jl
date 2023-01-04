module JobTools
export
    JobInfo,
    TaskInfo,
    TaskMaker,
    task,
    make_tasks

include("taskinfo.jl")
include("jobinfo.jl")
include("taskmaker.jl")

end
