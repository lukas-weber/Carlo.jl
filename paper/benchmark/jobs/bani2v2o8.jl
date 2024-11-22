# bani2v2o8.jl

using Carlo
using Carlo.JobTools
using StochasticSeriesExpansion

tm = TaskMaker()
tm.sweeps = 80000
tm.thermalization = 10000
tm.binsize = 100

temperatures = range(0.05, 4, 20)
system_sizes = [10, 20]

tm.model = MagnetModel
tm.S = 1
tm.J = 1
tm.Dz = 0.005645 # D^{QMC}_{EP(XY)}/J^{QMC}_n from PRB 104, 065502 

tm.measure = [:magnetization]
for L in system_sizes
    tm.lattice = (unitcell = UnitCells.honeycomb, size = (L, L))

    for T in temperatures
        tm.T = T
        task(tm)
    end
end

job = JobInfo(
    splitext(@__FILE__)[1],
    StochasticSeriesExpansion.MC;
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    tasks = make_tasks(tm),
)

start(job, ARGS)
