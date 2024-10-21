@struct_equal Random.Xoshiro

@testset "Random wrapper" begin
    rng = Random.Xoshiro(141376357, 3244512, 3768, 5326171454)
    for i = 1:1000
        rand(rng)
    end

    @test rand(rng, UInt32) == 1232139906
    @test rand(rng, UInt32) == 1416645027
    @test rand(rng, UInt32) == 1517520173

    @test test_checkpointing(rng)
end
