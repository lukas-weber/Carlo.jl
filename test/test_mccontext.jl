using LoadLeveller

@struct_equal LoadLeveller.MCContext

@testset "MCContext" begin
    thermalization = 10
    ctx = LoadLeveller.MCContext{Random.Xoshiro}(
        Dict("binsize" => 3, "seed" => 123, "thermalization" => thermalization),
    )

    @test ctx.rng == Random.Xoshiro(123)

    LoadLeveller.measure!(ctx, :test, 2.0)

    tmp_hdf5_file() do file
        LoadLeveller.write_measurements!(ctx, open_group(file, "/"))
    end

    @test test_checkpointing(ctx)
end
