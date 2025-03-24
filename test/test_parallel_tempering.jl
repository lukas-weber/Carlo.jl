@struct_equal Carlo.ParallelTemperingMC
@struct_equal TestTemperedMC
@struct_equal Carlo.ParallelMeasurements


struct FakeComm
    size::Int
    rank::Int
end

MPI.Comm_size(f::FakeComm) = f.size
MPI.Comm_rank(f::FakeComm) = f.rank

@testset "ParallelTemperingMC" begin

    mktempdir() do tmpdir
        @testset "checkpointing" begin

            params = Dict(
                :sweeps => 1000,
                :thermalization => 100,
                :binsize => 100,
                :parallel_tempering => (;
                    mc = TestTemperedMC,
                    parameter = :μ,
                    values = [0, 1, 1.5, 1.7, 2],
                    interval = 100,
                ),
                :_comm => FakeComm(5, 2),
            )
            MPI.Init()

            mc = ParallelTemperingMC(params)
            mc2 = ParallelTemperingMC(params)

            mc.chain_idx = 2
            mc.child_mc.μ = params[:parallel_tempering].values[2]
            mc.child_mc.x = 12

            Carlo.add_sample!(mc.parallel_measure, :test, 1)
            Carlo.add_sample!(mc.parallel_measure, :test, 2)
            Carlo.add_sample!(mc.parallel_measure, :test2, [1, 2])
            Carlo.add_sample!(mc.parallel_measure, :test, 3)
            Carlo.add_sample!(mc.parallel_measure, :test2, [3, 4])


            h5open("$tmpdir/tmp.h5", "w") do f
                Carlo.write_checkpoint(
                    mc,
                    create_group(f, "parallel_tempering"),
                    MPI.COMM_SELF,
                )
                @test mc2 != mc
                Carlo.read_checkpoint!(mc2, f["parallel_tempering"], MPI.COMM_SELF)
                @test mc2 == mc
            end
        end

        @testset "mpi" begin
            μs = [0, 1, 1.5, 1.7]

            job = make_test_job(
                "$tmpdir/parallel_tempering",
                10000;
                binsize = 200,
                thermalization = 3000,
                mc = ParallelTemperingMC,
                ranks_per_run = length(μs),
                ntasks = 1,
                parallel_tempering = (;
                    mc = TestTemperedMC,
                    parameter = :μ,
                    values = μs,
                    interval = 1,
                ),
            )

            run_test_job_mpi(job; num_ranks = length(μs) + 1)

            results = ResultTools.dataframe(JT.result_filename(job))

            X² = results[1]["X²"]
            ref_X² = test_distribution_x².(μs)
            X = results[1]["X"]
            ref_X = test_distribution_x.(μs)
            @test stdscore(sum((X² - ref_X²) .^ 2), 0) < 3
            @test stdscore(sum((X - ref_X) .^ 2), 0) < 3
            @test iszero(results[1]["Zero"])
        end
    end
end
