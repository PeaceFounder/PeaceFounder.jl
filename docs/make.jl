using Documenter
using PeaceFounder
makedocs(sitename="PeaceFounder.jl",pages = ["index.md"])

deploydocs(
     repo = "github.com/PeaceFounder/PeaceFounder.jl.git",
 )
