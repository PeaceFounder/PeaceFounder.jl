module Analysis

using PeaceVote: voters!, BraidChain, Deme
using PeaceVote: AbstractProposal, AbstractVote, Intent
#using ..Types: Proposal, Vote


### One still needs to find the proposal with in the chain. For that additional uniqness property is still valuable.
function normalcount(index::Int,proposal::AbstractProposal,deme::Deme) ### Here I could have 
    messages = BraidChain(deme).records

    voters = Set()
    voters!(voters,messages[1:index])

    ispvote(msg) = typeof(msg) <: Intent{T} where T<:AbstractVote && msg.reference in voters && msg.document.pid==index

    tally = zeros(Int,length(proposal.options))

    for msg in messages[end:-1:index]
        if ispvote(msg)
            tally[msg.document.vote] += 1
            pop!(voters,msg.reference)
        end
    end
    
    return tally
end

preferentialcount(proposal::AbstractProposal,deme::Deme) = error("Not yet implemented")

quadraticcount(proposal::AbstractProposal,deme::Deme) = error("Not yet implemented")


end
