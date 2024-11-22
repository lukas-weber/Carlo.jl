using Carlo
using Carlo.JobTools
using StochasticSeriesExpansion
using Random

tm = TaskMaker()
tm.sweeps = 100000
tm.thermalization = 10000
tm.binsize = 100

tm.model = ClusterModel
tm.inner_model = MagnetModel
tm.cluster_bases = (StochasticSeriesExpansion.ClusterBases.dimer,)

tm.measure_quantum_numbers = [(; name = Symbol(), quantum_number = 2)]
tm.parameter_map = (; J = vcat([:Jperp], repeat([:Jpar], 8)))

tm.Jpar = 1
tm.Jperp = 0.5

βs = range(1, 10, 16)
Ls = [30]

for L in Ls
    tm.lattice = (
        unitcell = StochasticSeriesExpansion.UnitCells.fully_frust_square_bilayer,
        size = (L, L),
    )
    for β in βs
        tm.init_opstring_cutoff = 160000 * β / maximum(βs)
        tm.init_num_worms = 8
        tm.num_worms_attenuation_factor = 0.0
        tm.T = 1 / β
        tm.Lx = L
        tm.Ly = L
        task(tm)
    end
end

job = JobInfo(
    "~/ceph/carlo/ffb",
    StochasticSeriesExpansion.MC;
    run_time = "24:00:00",
    checkpoint_time = "30:00",
    rng = Random.MersenneTwister,
    tasks = make_tasks(tm),
)

start(job, ARGS)
