
### I could put theese things in the ledgers submodule

function binary(x)
    io = IOBuffer()
    serialize(io,x)
    return take!(io)
    #println(String(take!(io)))
end

deserialize(record::Record,type::Type) = deserialize(IOBuffer(record.data),type)

function load(ledger::AbstractLedger)
    chain = Union{Certificate,Contract}[]

    for record in records(ledger)
        if dirname(record)=="members"

            id = deserialize(IOBuffer(record.data),Certificate{ID})
            push!(chain,id)

        elseif dirname(record)=="braids"

            braid = deserialize(IOBuffer(record.data),Contract{Braid})
            push!(chain,braid)

        elseif dirname(record)=="votes"

            vote = deserialize(IOBuffer(record.data),Certificate{Vote})
            push!(chain,vote)

        elseif dirname(record)=="proposals"

            proposal = deserialize(IOBuffer(record.data),Certificate{Proposal})
            push!(chain,proposal)

        end
    end
    return chain
end

function getrecord(ledger::AbstractLedger,fname::AbstractString)
    for record in records(ledger)
        if record.fname == fname
            return record
        end
    end
end


serialize(ledger::AbstractLedger,data,fname::AbstractString) = record!(ledger,fname,binary(data))


serialize(ledger::AbstractLedger,id::Certificate{ID}) = record!(ledger,"members/$(id.document.id)",binary(id))

function serialize(ledger::AbstractLedger,vote::Certificate{Vote}) 
    pid = vote.document.pid
    uuid = hash(vote.signature)
    record!(ledger,"votes/$pid-$uuid",binary(vote)) ### We may also use length of the ledger 
end

function serialize(ledger::AbstractLedger,proposal::Certificate{Proposal})
    msg = proposal.document.msg
    propid = hash(msg)
    uuid = hash(proposal.signature)
    record!(ledger,"proposals/$propid-$uuid",binary(proposal))
end

function serialize(ledger::AbstractLedger,braid::Contract{Braid})
    uuid = hash(braid.signatures)
    record!(ledger,"braids/$uuid",binary(braid))
end

### This is the only part which depends on TOML. I could replace TOML with serialize and deserialize methods from DemeNet


