@testset "Results" begin
    result_obs = Carlo.ResultObservable(
        Int64(100),
        Int64(3),
        [1.0, 2.0, 3.0],
        [0.1, 0.1, 0.1],
        [0.1, 0.2, 0.3],
        zeros(3, 4),
    )

    repr = JSON.parse(JSON.json(result_obs, 1))
    @test repr["mean"] == result_obs.mean
    @test repr["error"] == result_obs.error
end

@testset "ResultTools" begin
    @testset "recursive_stack" begin
        v = reshape(1:60, 3, 5, 4)
        @test v == ResultTools.recursive_stack(JSON.parse(JSON.json(v)))

        @test ResultTools.recursive_stack(nothing) === nothing
        @test ResultTools.recursive_stack([nothing, nothing]) == [nothing, nothing]
    end
    @testset "recursive_stack_Dict" begin
        dict_complex = Dict("re" => 1.5, "im" => -2.0)
        @test ResultTools.recursive_stack(dict_complex) == Complex(1.5, -2.0)

        dict_bad = Dict("real" => 1.5, "imaginary" => -2.0)
        @test_throws String ResultTools.recursive_stack(dict_bad)

        v_dict = [Dict("re" => 1, "im" => 2), Dict("re" => 3, "im" => 4)]
        @test ResultTools.recursive_stack(v_dict) == [Complex(1, 2), Complex(3, 4)]

        v_nested_dict = [
            [Dict("re" => 1, "im" => 1), Dict("re" => 2, "im" => 2)],
            [Dict("re" => 3, "im" => 3), Dict("re" => 4, "im" => 4)],
        ]
        expected_matrix = [
            Complex(1, 1) Complex(2, 2)
            Complex(3, 3) Complex(4, 4)
        ]
        @test permutedims(ResultTools.recursive_stack(v_nested_dict)) == expected_matrix
    end
end
