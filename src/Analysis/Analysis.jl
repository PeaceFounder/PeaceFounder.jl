module Analysis

using PeaceVote: Proposal, voters!, Vote, Option, BraidChain, Deme

function normalcount(proposal::Proposal,deme::Deme) ### Here I could have 
    messages = BraidChain(deme).records

    index = findfirst(item -> item==proposal,messages)
    voters = Set()
    voters!(voters,messages[1:index])

    ispvote(msg) = typeof(msg)==Vote && msg.id in voters && typeof(msg.msg)==Option && msg.msg.pid==proposal.uuid

    tally = zeros(Int,length(proposal.options))

    for msg in messages[end:-1:index]
        if ispvote(msg)
            tally[msg.msg.vote] += 1
            pop!(voters,msg.id)
        end
    end
    
    return tally
end

preferentialcount(proposal::Proposal,deme::Deme) = error("Not yet implemented")

quadraticcount(proposal::Proposal,deme::Deme) = error("Not yet implemented")


end
