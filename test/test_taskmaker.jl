@struct_equal TaskInfo


@testset "TaskMaker" begin
    tm = TaskMaker()

    tm.foo = 1
    tm.bar = "hi"

    task(tm, baz = 2.4)
    tm.bar = "ho"
    task(tm, baz = 1)

    @test make_tasks(tm) == [
        TaskInfo("task0001", Dict(:baz => 2.4, :bar => "hi", :foo => 1)),
        TaskInfo("task0002", Dict(:baz => 1, :bar => "ho", :foo => 1)),
    ]
end
