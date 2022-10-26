function run(
    parameter_file::AbstractString,
    runner::Type{R},
    mc::Type{MC},
) where {MC<:AbstractMC,R<:AbstractRunner}
    job = JobInfo(parameter_file)
    create_job_directory(job)
    runner = runner(job, MC)
    start!(runner)
end
