### Let's look into theese two types


# struct Proposal <: AbstractProposal
#     uuid ### just so one could find it
#     id ### the person issueing the proposal
#     msg
#     options### just a list of messages
# end


# struct Option <: AbstractOption
#     pid ### the id of the proposal
#     vote ### just a number or perhaps other choice
# end

# Option(p::Proposal,choice) =  Option(p.uuid,choice)


struct BraidChain # <: AbstractBraidChain
    records
end


#function records(rawrecords::Vector{T},notary::Notary) where T # Vector{Record} if it infers corectly
function BraidChain(rawrecords::Vector,notary::Notary)
    messages = []
    for record in rawrecords
        if dirname(record)=="members"

            cert = deserialize(IOBuffer(record.data),Certificate{PFID})
            id = Intent(cert,notary)
            push!(messages,id)

        elseif dirname(record)=="braids"

            contr = deserialize(IOBuffer(record.data),Contract{Braid})
            braid = Consensus(contr,notary)
            push!(messages,braid)

        elseif dirname(record)=="votes"

            cert = deserialize(IOBuffer(record.data),Certificate{Vote})
            vote = Intent(cert,notary)
            push!(messages,vote)

        elseif dirname(record)=="proposals"

            cert = deserialize(IOBuffer(record.data),Certificate{Proposal})
            proposal = Intent(cert,notary)
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

# import Base.count
# function count(proposal::Proposal,messages::Vector) ### Here I could have 
#     #voters = PeaceVote.voters(proposal,messages) # I need a index

#     index = findfirst(item -> item==proposal,messages)
#     voters = Set()
#     voters!(voters,messages[1:index])

#     ispvote(msg) = typeof(msg)==Vote && msg.id in voters && typeof(msg.msg)==Option && msg.msg.pid==proposal.uuid

#     tally = zeros(Int,length(proposal.options))

#     for msg in messages[end:-1:index]
#         if ispvote(msg)
#             tally[msg.msg.vote] += 1
#             pop!(voters,msg.id)
#         end
#     end
    
#     return tally
# end

# count(proposal::Proposal,braidchain::BraidChain) = count(proposal,braidchain.records)
