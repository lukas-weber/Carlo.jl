@testset "Task Selection" begin
    sweeps = [100, 10, 10, 101, 10]
    tasks = map(s -> LoadLeveller.RunnerTask(100, s, "", 0), sweeps)

    @test LoadLeveller.get_new_task_id(tasks, 1) == 2
    @test LoadLeveller.get_new_task_id(tasks, 2) == 3
    @test LoadLeveller.get_new_task_id(tasks, 3) == 5
    @test LoadLeveller.get_new_task_id(tasks, 4) == 5
    @test LoadLeveller.get_new_task_id(tasks, 5) == 2
end
