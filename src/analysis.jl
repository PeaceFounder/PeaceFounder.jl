using PeaceVote: Proposal, Vote, Option, voters!

using Synchronizers: Ledger


function inout(uuid,msgs,signatures,notary::Notary)
    input = Set()
    for s in signatures
        id = notary.verify(msgs,s)
        @assert id!=nothing "braid with $uuid is not valid"
        push!(input,id)
    end
    
    output = Set(msgs)
    
    @assert length(input)==length(output)

    return input,output
end

### Now I need to test that I can read this thing.
function braidchain(ledger::Ledger,notary::Notary)
    messages = []
    for record in ledger.records
        if dirname(record.fname)=="members"
            
            _demespec = DemeSpec(envelope.uuid)
            _notary = Notary(demespec) ### Each time one would need to construct a new notary object which is quite daunting! Better would be to use a dictionary for a chache
            cert = Serialization.deserialize(IOBuffer(record.data))
            memberid, signerid = PeaceVote.unwrap(cert,_notary) 
            ticket = PeaceVote.Ticket(_demespec.uuid,signerid,memberid.id)
            push!(messages,ticket)

        elseif dirname(record.fname)=="braids"

            ballot = Serialization.deserialize(IOBuffer(record.data))
            input,output = inout(basename(record.fname),ballot...,notary)
            braid = PeaceVote.Braid(basename(record.fname),nothing,input,output) 
            push!(messages,braid)

        elseif dirname(record.fname)=="votes"

            msg,signature = Serialization.deserialize(IOBuffer(record.data))
            id = notary.verify(msg,signature)
            @assert id!=nothing "Invalid vote."
            vote = Vote(basename(record.fname),id,msg)
            push!(messages,vote)

        elseif dirname(record.fname)=="proposals"

            data,signature = Serialization.deserialize(IOBuffer(record.data))
            id = notary.verify(data,signature)
            @assert id!=nothing "Invalid proposal."
            proposal = Proposal(basename(record.fname),id,data...)
            push!(messages,proposal)
        end
    end
    return messages
end

braidchain(deme::ThisDeme) = braidchain(deme.ledger,deme.notary)

#braidchain(datadir::AbstractString,verify::Function,id::Function) = braidchain(Ledger(datadir),verify,id)


### One may first write 
#braidchain(ledger::Ledger) = braidchain(ledger,verify,id)

#braidchain() = PeaceFounder.braidchain(datadir(),verify,id)

#members(braidchain) = PeaceFounder.loadmembers(braidchain,BraidChainConfig().membersca)


import Base.count
function count(proposal::Proposal,messages::Vector) 
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
