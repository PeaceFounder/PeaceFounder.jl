using Documenter
using PeaceFounder


cp((@__DIR__) * "/../README.md", (@__DIR__) * "/src/index.md", force = true)

makedocs(
    sitename = "PeaceFounder.jl",
    format = Documenter.HTML(),
    modules = [PeaceFounder.Model, PeaceFounder.Client],
    pages = [
        #"index.md",
        
        "Overview" => "overview.md",
        "Setup" => "setup.md",
        "Audit" => "audit.md",
        "API" => [
            "REST" => "schema.md",
            "PeaceFounder.Model" => "model_api.md"
        ]
    ],
    #repo = "PeaceFounder/PeaceFounder.jl"
    #repo = "github.com/PeaceFounder/PeaceFounder.jl.git"
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/PeaceFounder/PeaceFounder.jl.git"
)
