function binary(x)
    io = IOBuffer()
    serialize(io,x)
    return take!(io)
end


function load(ledger::AbstractLedger)
    chain = Union{Certificate,Contract}[]

    for record in records(ledger)
        if dirname(record)=="members"

            id = deserialize(IOBuffer(record.data),Certificate{PFID})
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

serialize(ledger::AbstractLedger,id::Certificate{PFID}) = record!(ledger,"members/$(id.document.id.id)",binary(id))

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


function serialize(ledger::AbstractLedger,config::Certificate{SystemConfig})
    fname = ledger.dir * "/PeaceFounder.toml"
    mkpath(dirname(fname))

    dict = Dict(config)
    
    open(fname, "w") do io
        TOML.print(io, dict)
    end
end


function serialize(ledger::AbstractLedger,config::SystemConfig)
    fname = ledger.dir * "/PeaceFounder.toml"
    mkpath(dirname(fname))

    dict = Dict(config)
    
    open(fname, "w") do io
        TOML.print(io, dict)
    end
end

function deserialize(ledger::AbstractLedger,type::Type{Certificate{SystemConfig}})
    fname = ledger.dir * "/PeaceFounder.toml"
    @assert isfile(fname) "Config file not found!"
    dict = TOML.parsefile(fname)
    return Certificate{SystemConfig}(dict)
end


function deserialize(ledger::AbstractLedger,type::Type{SystemConfig})
    fname = ledger.dir * "/PeaceFounder.toml"
    @assert isfile(fname) "Config file not found!"
    dict = TOML.parsefile(fname)
    return SystemConfig(dict)
end
