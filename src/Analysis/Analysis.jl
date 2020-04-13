module Analysis

using DemeNet: Intent
using PeaceVote.BraidChains: voters!, ID, attest
using PeaceVote.Plugins: AbstractProposal, AbstractVote
using ..Types: Proposal, Vote, BraidChain
using ..Ledgers: load

### One still needs to find the proposal with in the chain. For that additional uniqness property is still valuable.

function normalcount(proposal::Proposal,voters::Set{ID},messages)
end


function normalcount(index::Int,chain::BraidChain) ### Here I could have 
    loadedledger = load(chain.ledger) #BraidChain(deme).records
    messages = attest(loadedledger,chain.deme.notary)
    intentproposal = messages[index]
    @assert typeof(intentproposal) <: Intent{T} where T<:AbstractProposal "Not a proposal"

    proposal = intentproposal.document

    voters = Set{ID}()
    voters!(voters,messages[1:index])


    ispvote(msg) = typeof(msg) <: Intent{T} where T<:Vote && msg.reference in voters && msg.document.pid==index
    
    tally = zeros(Int,length(proposal.options))

    for msg in messages[end:-1:index]
        if ispvote(msg)
            tally[msg.document.vote] += 1
            pop!(voters,msg.reference)
        end
    end
    
    return tally
end


preferentialcount(proposal::AbstractProposal,deme::BraidChain) = error("Not yet implemented")

quadraticcount(proposal::AbstractProposal,deme::BraidChain) = error("Not yet implemented")


end
