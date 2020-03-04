struct BraidChain # <: AbstractBraidChain
    records
end


function inout(uuid,msgs,signatures,notary::Notary)
    input = Set()
    for s in signatures
        id = verify(msgs,s,notary)
        @assert id!=nothing "braid with $uuid is not valid"
        push!(input,id)
    end
    
    output = Set(msgs)
    
    @assert length(input)==length(output)

    return input,output
end

#function records(rawrecords::Vector{T},notary::Notary) where T # Vector{Record} if it infers corectly
function BraidChain(rawrecords::Vector,notary::Notary)
    messages = []
    for record in rawrecords
        if dirname(record)=="members"
            
            cert = loadrecord(record)           
            memberid, signerid = PeaceVote.unwrap(cert) 
            ticket = PeaceVote.Ticket(signerid...,memberid.id)
            push!(messages,ticket)

        elseif dirname(record)=="braids"

            ballot = loadrecord(record)
            input,output = inout(basename(record),ballot...,notary)
            braid = PeaceVote.Braid(basename(record),nothing,input,output) 
            push!(messages,braid)

        elseif dirname(record)=="votes"

            msg,signature = loadrecord(record)
            id = verify(msg,signature,notary)
            @assert id!=nothing "Invalid vote."
            vote = Vote(basename(record),id,msg)
            push!(messages,vote)

        elseif dirname(record)=="proposals"

            pdata,signature = loadrecord(record)
            id = verify(pdata,signature,notary)
            @assert id!=nothing "Invalid proposal."
            proposal = Proposal(basename(record),id,pdata...)
            push!(messages,proposal)

        end
    end
    return BraidChain(messages)
end

BraidChain(ledger,notary::Notary) = BraidChain(records(ledger),notary)
BraidChain(deme::Deme) = BraidChain(deme.ledger,deme.notary)

#rawrecords(braidchain::BraidChain) = rawrecords(braidchain.ledger)

#records(braidchain::BraidChain,notary::Notary) = records(rawrecords(braidchain),notary::Notary)
#records(deme::Deme) = records(deme.braidchain,deme.notary)

#braidchain(datadir::AbstractString,verify::Function,id::Function) = braidchain(Ledger(datadir),verify,id)


### One may first write 
#braidchain(ledger::Ledger) = braidchain(ledger,verify,id)

#braidchain() = PeaceFounder.braidchain(datadir(),verify,id)

#members(braidchain) = PeaceFounder.loadmembers(braidchain,BraidChainConfig().membersca)

### I could make this outside. I could impplement a method rawrecords and records (makes sense because I have the recorder!)

import Base.count
function count(proposal::Proposal,messages::Vector) ### Here I could have 
    #voters = PeaceVote.voters(proposal,messages) # I need a index

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

count(proposal::Proposal,braidchain::BraidChain) = count(proposal,braidchain.records)
