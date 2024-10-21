using Documenter, Carlo, Carlo.JobTools

makedocs(
    sitename = "Carlo.jl",
    format = Documenter.HTML(prettyurls = false),
    checkdocs = :all,
    pages = [
        "index.md",
        "abstract_mc.md",
        "Advanced Topics" => [
            "evaluables.md",
            "jobtools.md",
            "resulttools.md",
            "rng.md",
            "parallel_run_mode.md",
        ],
        "Extras" => ["parallel_tempering.md"],
    ],
)

deploydocs(repo = "github.com/lukas-weber/Carlo.jl.git")
