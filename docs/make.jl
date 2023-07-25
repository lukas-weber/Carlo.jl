using Documenter, Carlo, Carlo.JobTools

makedocs(
    sitename = "Carlo",
    format = Documenter.HTML(prettyurls = false),
    pages = [
        "index.md",
        "cli.md",
        "abstract_mc.md",
        "Advanced Topics" => ["evaluables.md", "jobtools.md", "resulttools.md", "rng.md"],
    ],
)

deploydocs(repo = "github.com/lukas-weber/Carlo.jl.git")
