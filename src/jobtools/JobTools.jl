module JobTools
export JobInfo, TaskInfo, TaskMaker, task, make_tasks, result_filename

include("taskinfo.jl")
include("jobinfo.jl")
include("taskmaker.jl")

end
