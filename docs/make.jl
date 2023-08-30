using Documenter
using PeaceFounder


function copy_if_changed(source, destination)
    
    if !isfile(destination)
        cp(source, destination)
        return nothing
    end

    if !(readlines(source) == readlines(destination))
        @info "README.md updated"
        cp(source, destination, force = true)
        return nothing
    end
end

#cp((@__DIR__) * "/../README.md", (@__DIR__) * "/src/index.md", force = true)
copy_if_changed((@__DIR__) * "/../README.md", (@__DIR__) * "/src/index.md")

makedocs(
    sitename = "PeaceFounder.jl",
    format = Documenter.HTML(),
    modules = [PeaceFounder.Model, PeaceFounder.Client],
    pages = [
        "index.md",
        "Overview" => "overview.md",
        "Setup" => "setup.md",
        "Client" => "client.md",
        "Audit" => "audit.md",
        "API" => [
            "REST" => "schema.md",
            "PeaceFounder.Model" => "model_api.md",
            "PeaceFounder.AuditTools" => "audittools.md",
            "PeaceFounder.Schedulers" => "schedulers.md"
        ]
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/PeaceFounder/PeaceFounder.jl.git"
)
