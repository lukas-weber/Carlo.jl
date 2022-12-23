
@testset "Task Selection" begin
    tasks = [
        LoadLeveller.RunnerTask(100, 100, 0)
        LoadLeveller.RunnerTask(100, 10, 0)
        LoadLeveller.RunnerTask(100, 10, 0)
        LoadLeveller.RunnerTask(100, 101, 0)
        LoadLeveller.RunnerTask(100, 10, 0)
    ]

    @test LoadLeveller.get_new_task_id(tasks, 1) == 2
    @test LoadLeveller.get_new_task_id(tasks, 2) == 3
    @test LoadLeveller.get_new_task_id(tasks, 3) == 5
    @test LoadLeveller.get_new_task_id(tasks, 4) == 5
    @test LoadLeveller.get_new_task_id(tasks, 5) == 2
end
