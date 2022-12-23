using JSON

@testset "JobInfo" begin
    tm = LoadLeveller.TaskMaker()
    LoadLeveller.task(tm; test=1)
    LoadLeveller.task(tm; test=2)
    LoadLeveller.task(tm; test=3)

    tmpdir = mktempdir()
    
    job = LoadLeveller.JobInfo(tmpdir * "/test"; tasks=LoadLeveller.generate_tasks(tm),
        checkpoint_time = "15:00",
        run_time = "30:00",
    )

    LoadLeveller.create_job_directory(job)
    for task in job.tasks
        @test isdir(LoadLeveller.task_dir(job, task))
        open(LoadLeveller.task_dir(job,task) * "/results.json", "w") do io
            write(io, "{}")
        end
    end

    LoadLeveller.concatenate_results(job)

    results = open(JSON.parse, "$(job.dir)/../$(job.name).results.json", "r")

    @test results == [Dict(), Dict(), Dict()]
    
end
