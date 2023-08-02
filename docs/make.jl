using Documenter, Carlo, Carlo.JobTools

makedocs(
    sitename = "Carlo",
    format = Documenter.HTML(prettyurls = false),
    checkdocs = :all,
    pages = [
        "index.md",
        "cli.md",
        "abstract_mc.md",
        "Advanced Topics" => ["evaluables.md", "jobtools.md", "resulttools.md", "rng.md", "parallel_run_mode.md"],
    ],
)

deploydocs(repo = "github.com/lukas-weber/Carlo.jl.git")
