@struct_equal TaskInfo


@testset "TaskMaker" begin
    tm = TaskMaker()

    tm.sweeps = 2
    tm.thermalization = 1
    tm.binsize = "hi"

    task(tm, baz = 2.4)
    tm.binsize = "ho"
    task(tm, baz = 1)

    @test make_tasks(tm) == [
        TaskInfo(
            "task0001",
            Dict(:baz => 2.4, :binsize => "hi", :thermalization => 1, :sweeps => 2),
        ),
        TaskInfo(
            "task0002",
            Dict(:baz => 1, :binsize => "ho", :thermalization => 1, :sweeps => 2),
        ),
    ]
end
