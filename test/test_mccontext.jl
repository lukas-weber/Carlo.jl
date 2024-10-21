@struct_equal Carlo.MCContext

@testset "MCContext" begin
    thermalization = 10
    ctx = Carlo.MCContext{Random.Xoshiro}(
        Dict(:binsize => 3, :seed => 123, :thermalization => thermalization),
    )

    @test ctx.rng == Random.Xoshiro(123)

    Carlo.measure!(ctx, :test, 2.0)

    tmp_hdf5_file() do file
        Carlo.write_measurements!(ctx, open_group(file, "/"))
    end

    @test test_checkpointing(ctx, type = Carlo.MCContext{Random.Xoshiro})
end
