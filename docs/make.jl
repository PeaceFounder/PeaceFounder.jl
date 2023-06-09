using Documenter
using PeaceFounder

makedocs(
    sitename = "PeaceFounder",
    format = Documenter.HTML(),
    modules = [PeaceFounder],
    pages = [
        "index.md",
        "Overview" => "overview.md",
        "Setup" => "setup.md",
        "Audit" => "audit.md"
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/PeaceFounder/PeaceFounder.jl.git"
)
