@struct_equal Carlo.MCContext

@testset "MCContext" begin
    thermalization = 10
    ctx = Carlo.MCContext{Random.Xoshiro}(
        Dict(:binsize => 3, :seed => 123, :thermalization => thermalization),
    )

    @test ctx.rng == Random.Xoshiro(123)

    register_observable!(ctx, :test2; binsize = 2)

    Carlo.measure!(ctx, :test, 2.0)

    Carlo.measure!(ctx, :test2, 2.0)
    Carlo.measure!(ctx, :test2, 3)
    Carlo.measure!(ctx, :test2, 4)

    tmp_hdf5_file() do file
        Carlo.write_measurements!(ctx, open_group(file, "/"))

        @test read(file, "/observables/test2/samples") ≈ [2.5]
        @test read(file, "/observables/test2/bin_length") ≈ 2
    end

    @test test_checkpointing(ctx, type = Carlo.MCContext{Random.Xoshiro})
end
