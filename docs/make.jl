dirname(@__DIR__) in LOAD_PATH || Base.push!(LOAD_PATH, dirname(@__DIR__))

using Documenter
using PeaceFounder
using JSON3

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

Documenter.HTML(assets = [
    asset("assets/swagger/swagger@5.7.2/swagger-ui-bundle.js", class=:js, islocal=true),
    #asset(joinpath(@__DIR__, "src/assets/swagger/swagger@5.7.2/swagger-ui-bundle.js"), class=:js, islocal=true),
])


makedocs(
    sitename = "PeaceFounder.jl",
    repo = Documenter.Remotes.GitHub("PeaceFounder", "PeaceFounder.jl"),
    format = Documenter.HTML(
        assets = [
            asset("https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui-bundle.js", class=:js, load_early=true),
            asset("https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui.css", class=:css, load_early=true) # for dark theme to work
        ]

    ),
    modules = [PeaceFounder.Model, PeaceFounder.Client],
    pages = [
        "index.md",
        "Overview" => "overview.md",
        "Setup" => "setup.md",
        "Client" => "client.md",
        "Audit" => "audit.md",
        "API" => [
            "HTTP" => "schema.md",
            "PeaceFounder.Model" => "model_api.md",
            "PeaceFounder.AuditTools" => "audittools.md",
            "PeaceFounder.Schedulers" => "schedulers.md"
        ]
    ],
)


# Adding a schema to assets directory after the build

SCHEMA_PATH = joinpath(@__DIR__, "build/assets/schema.json")
rm(SCHEMA_PATH, force=true)

open(SCHEMA_PATH, "w") do file
    schema = PeaceFounder.Service.OxygenInstance.getschema()
    JSON3.write(file, schema)
end

open(joinpath(@__DIR__, "build/assets/themes/documenter-dark.css"), "a") do file
    contents = read(joinpath(@__DIR__, "assets/swagger-dark.css"))
    write(file, contents)
end


# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.

deploydocs(repo = "github.com/PeaceFounder/PeaceFounder.jl.git")
