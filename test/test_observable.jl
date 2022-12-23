using LoadLeveller

@struct_equal LoadLeveller.Observable

@testset "Observable" begin
    bin_length = 124
    obs = LoadLeveller.Observable{Float64}(bin_length, 2)

    LoadLeveller.add_sample!(obs, [1, 1.2])
    @test test_checkpointing(obs)
    for i = 2:bin_length
        LoadLeveller.add_sample!(obs, [i, 1.2])
    end
    @test obs.current_bin_filling == 0
    @test size(obs.samples) == (2, 2)
    @test isapprox(obs.samples[:, 1], [(bin_length + 1) / 2, 1.2])

    for i = 1:3*bin_length+10
        LoadLeveller.add_sample!(obs, [1, 1.2])
    end
    @test size(obs.samples, 2) == 5

    tmpdir = mktempdir()
    h5open(tmpdir * "/test.h5", "w") do file
        LoadLeveller.write_measurements!(obs, create_group(file, "obs"))
        @test size(obs.samples, 2) == 1
        @test size(file["obs/samples"]) == (2, 4)
    end
end
