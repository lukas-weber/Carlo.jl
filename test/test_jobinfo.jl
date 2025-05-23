@testset "JobInfo" begin
    tm = JT.TaskMaker()
    tm.thermalization = 100
    tm.sweeps = 7
    tm.binsize = 10
    task(tm; test = 1)
    task(tm; test = 2)
    task(tm; test = 3)

    tmpdir = mktempdir()

    job = JT.JobInfo(
        tmpdir * "/test",
        TestMC;
        tasks = make_tasks(tm),
        checkpoint_time = "15:00",
        run_time = "30:00",
    )

    JT.create_job_directory(job)
    for task in job.tasks
        @test isdir(JT.task_dir(job, task))
        open(JT.task_dir(job, task) * "/results.json", "w") do io
            write(io, "{}")
        end
    end

    JT.concatenate_results(job)

    results = open(JSON.parse, "$(job.dir)/../$(job.name).results.json", "r")

    @test results == [Dict(), Dict(), Dict()]

end

@testset "Parse Duration" begin
    @test_throws ErrorException JT.parse_duration("1-10")
    @test_throws ErrorException JT.parse_duration("1-10:00")
    @test_throws ErrorException JT.parse_duration("10:")
    @test_throws ErrorException JT.parse_duration("10::00")
    @test_throws ErrorException JT.parse_duration("a:2:00")
    @test JT.parse_duration("10:00") == Minute(10)
    @test JT.parse_duration("100") == Second(100)
    @test JT.parse_duration("5:32:10") == Hour(5) + Minute(32) + Second(10)
    @test JT.parse_duration("100-12:04:31") == Day(100) + Hour(12) + Minute(4) + Second(31)
end
