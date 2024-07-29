using PrecompileTools
using ..JobTools

@setup_workload begin
    @compile_workload begin
        tm = TaskMaker()
        tm.thermalization = 10
        tm.sweeps = 10
        tm.binsize = 1
        tm.test = [1]

        task(tm, Lx = 2, T = 1)
    end
end
