using Documenter, LoadLeveller, LoadLeveller.JobTools

makedocs(
    sitename = "LoadLeveller",
    format = Documenter.HTML(prettyurls = false),
    pages = [
        "index.md",
        "cli.md",
        "abstract_mc.md",
        "Advanced Topics" => ["evaluables.md", "jobtools.md", "resulttools.md", "rng.md"],
    ],
)

deploydocs(repo = "github.com/lukas-weber/LoadLeveller.jl.git")
