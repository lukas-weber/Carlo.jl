using JSON
using Dates

@testset "JobInfo" begin
    tm = LoadLeveller.TaskMaker()
    LoadLeveller.task(tm; test = 1)
    LoadLeveller.task(tm; test = 2)
    LoadLeveller.task(tm; test = 3)

    tmpdir = mktempdir()

    job = LoadLeveller.JobInfo(
        tmpdir * "/test";
        tasks = LoadLeveller.generate_tasks(tm),
        checkpoint_time = "15:00",
        run_time = "30:00",
    )

    LoadLeveller.create_job_directory(job)
    for task in job.tasks
        @test isdir(LoadLeveller.task_dir(job, task))
        open(LoadLeveller.task_dir(job, task) * "/results.json", "w") do io
            write(io, "{}")
        end
    end

    LoadLeveller.concatenate_results(job)

    results = open(JSON.parse, "$(job.dir)/../$(job.name).results.json", "r")

    @test results == [Dict(), Dict(), Dict()]

end

@testset "Parse Duration" begin
    @test_throws ErrorException LoadLeveller.parse_duration("10:")
    @test_throws ErrorException LoadLeveller.parse_duration("10::00")
    @test_throws ErrorException LoadLeveller.parse_duration("a:2:00")
    @test LoadLeveller.parse_duration("10:00") == Dates.Second(60 * 10)
    @test LoadLeveller.parse_duration("100") == Dates.Second(100)
    @test LoadLeveller.parse_duration("5:32:10") == Dates.Second(5 * 60 * 60 + 32 * 60 + 10)
end
