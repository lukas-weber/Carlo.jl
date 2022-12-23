@struct_equal LoadLeveller.TaskInfo


@testset "TaskMaker" begin
    tm = LoadLeveller.TaskMaker()

    tm.foo = 1
    tm.bar = "hi"

    LoadLeveller.task(tm, baz=2.4)
    tm.bar = "ho"
    LoadLeveller.task(tm, baz=1)

    @test LoadLeveller.generate_tasks(tm) == [
        LoadLeveller.TaskInfo("task0001", Dict(
            :baz => 2.4,
            :bar => "hi",
            :foo => 1,
        )),
        LoadLeveller.TaskInfo("task0002", Dict(
            :baz => 1,
            :bar => "ho",
            :foo => 1,
        ))
    ]
end
