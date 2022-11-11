function run(
    ::Type{MC},
    parameter_file::AbstractString,
    runner::Type{R},
) where {MC<:AbstractMC,R<:AbstractRunner}
    job = JobInfo(parameter_file)
    create_job_directory(job)
    runner = runner(job, MC)
    start!(runner)
end
