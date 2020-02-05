using Documenter
using PeaceVote
makedocs(sitename="PeaceVote.jl",pages = ["index.md"])

deploydocs(
     repo = "github.com/PeaceFounder/PeaceVote.jl.git",
 )
