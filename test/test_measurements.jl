using LoadLeveller

@struct_equal LoadLeveller.Measurements

@testset "Measurements" begin
    meas = LoadLeveller.Measurements{Float64}(3)

    LoadLeveller.add_sample!(meas, :test, 1)
    LoadLeveller.add_sample!(meas, :test, 2)
    LoadLeveller.add_sample!(meas, :test, 3)
    LoadLeveller.add_sample!(meas, :test2, [3, 4])
    @test_throws ErrorException LoadLeveller.add_sample!(meas, :test2, 3)

    @test_throws ErrorException LoadLeveller.register_observable!(meas, :test2, 2, 3)
    LoadLeveller.register_observable!(meas, :test3, 2, 3)
    LoadLeveller.add_sample!(meas, :test3, [1, 2, 3])


    tmp_hdf5_file() do file
        root = open_group(file, "/")
        LoadLeveller.write_measurements!(meas, root)
    end
    @test test_checkpointing(meas)

end
