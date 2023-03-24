@testset "TaskInfo" begin
    @testset "required parameters" begin
        @test_throws ErrorException TaskInfo(
            "test",
            Dict(:thermalization => 100, :binsize => 10),
        )
        TaskInfo("test2", Dict(:thermalization => 100, :sweeps => 100, :binsize => 10))
    end

    @testset "list_run_files" begin
        tmpdir = mktempdir()
        files = ["0001", "0002", "10000", "9999999"]
        for filename in files
            h5open("$tmpdir/run$filename.dump.h5", "w") do file
                create_group(file, "context")
                file["context/sweeps"] = 4362
            end
        end
        open("$tmpdir/run0001.dump.h", "w") do file
        end
        open("$tmpdir/walke0001.dump.h5", "w") do file
        end

        @test JT.list_run_files(tmpdir, "dump\\.h5") ==
              map(x -> "$tmpdir/run$x.dump.h5", files)
    end

end
