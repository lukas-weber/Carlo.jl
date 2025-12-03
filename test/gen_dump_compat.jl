
# Storage format compatibility test file generator
#
# Run this file once per minor version release of Carlo to generate a new compatibility test.
# New releases will check against the compat files to ensure older simulations can still
# be continued and merged using a newer release.

using Carlo
include("test_mc.jl")
include("compat_job.jl")

function (@main)(args)
    job = compat_job([(VERSION, pkgversion(Carlo))]; dir = dirname(@__FILE__))
    start(Carlo.SingleScheduler, job)
    mv(JobTools.result_filename(job), "$(job.dir)/$(only(job.tasks).name).results.json")
end
