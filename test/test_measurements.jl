using Carlo

@struct_equal Carlo.Measurements

@testset "Measurements" begin
    meas = Carlo.Measurements(3)

    Carlo.add_sample!(meas, :test, 1)
    Carlo.add_sample!(meas, :test, 2)
    Carlo.add_sample!(meas, :test, 3)
    Carlo.add_sample!(meas, :test2, [3, 4])
    @test_throws TypeError Carlo.add_sample!(meas, :test2, 3)

    @test_throws ErrorException Carlo.register_observable!(meas, :test2, 2, (3,))
    Carlo.register_observable!(meas, :test3, 2, (3, 2))
    Carlo.add_sample!(meas, :test3, rand(3, 2))


    tmp_hdf5_file() do file
        root = open_group(file, "/")
        Carlo.write_measurements!(meas, root)
    end
    @test test_checkpointing(meas)

end
