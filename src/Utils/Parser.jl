module Parser

using Infiltrator


using ..Model: TicketID, Digest, Pseudonym, Signature, Seal, Member, Proposal, Vote, ChainState, Digest, Ballot, BallotBoxState, NonceCommitment, Lot, CastReceipt, CastRecord, Model, bytes, Admission

using Dates: DateTime

using JSON3 
using StructTypes

using StructTypes: constructfrom

using Base64: base64encode, base64decode


# Should be removed when canonicalization methods will be implemented.
Model.canonicalize(x) = marshal(x)


# Needed for canonicalize method
StructTypes.StructType(::Type{Signature}) = StructTypes.Struct()

StructTypes.StructType(::Type{Member}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Member}) = (:approval, :PoK)

StructTypes.StructType(::Type{Proposal}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Proposal}) = (:approval,)

StructTypes.StructType(::Type{Vote}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Vote}) = (:approval,)

StructTypes.StructType(::Type{ChainState}) = StructTypes.Struct()
#StructTypes.StructType(::Type{Digest}) = StructTypes.Struct()

StructTypes.StructType(::Type{Ballot}) = StructTypes.Struct()

StructTypes.StructType(::Type{BallotBoxState}) = StructTypes.Struct()
StructTypes.omitempties(::Type{BallotBoxState}) = (:tally,)

StructTypes.StructType(::Type{NonceCommitment}) = StructTypes.Struct()

StructTypes.StructType(::Type{Lot}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Lot}) = (:pulse,)

StructTypes.StructType(::Type{CastReceipt}) = StructTypes.Struct()
StructTypes.StructType(::Type{CastRecord}) = StructTypes.Struct()



StructTypes.StructType(::Type{TicketID}) = StructTypes.StringType()
Base.string(ticketid::TicketID) = base64encode(bytes(ticketid))
StructTypes.construct(::Type{TicketID}, s::AbstractString) = TicketID(base64decode(s))


StructTypes.StructType(::Type{Digest}) = StructTypes.StringType()
Base.string(x::Digest) = base64encode(bytes(x))
StructTypes.construct(::Type{Digest}, s::AbstractString) = Digest(base64decode(s))


StructTypes.StructType(::Type{Pseudonym}) = StructTypes.StringType()
Base.string(x::Pseudonym) = base64encode(bytes(x))
StructTypes.construct(::Type{Pseudonym}, s::AbstractString) = Pseudonym(base64decode(s))


StructTypes.StructType(::Type{Admission}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Admission}) = (:approval,)


function marshal(x) 
    io = IOBuffer()
    JSON3.write(io, x) 
    return take!(io)
end
    

#unmarshal(bytes, T::DataType) = JSON3.read(bytes, T)
unmarshal(bytes) = JSON3.read(bytes)


unmarshal(bytes, T::DataType) = JSON3.read(bytes, T)


StructTypes.StructType(::Type{Seal}) = StructTypes.CustomStruct()
StructTypes.lower(seal::Seal) = Dict(:id => seal.pbkey, :r => seal.sig.r, :s => seal.sig.s)

function StructTypes.construct(::Type{Seal}, x)
    
    id = constructfrom(Pseudonym, x["id"])
    sig = Signature(x["r"], x["s"])

    return Seal(id, sig)
end




# StructTypes.lower, StructTypes.lowertype could be used something alternative



function marshal(event::Tuple{TicketID, DateTime, Digest})

    ticketid, timestamp, auth_code = event
    payload = Dict(:ticketid => ticketid, :timestamp => timestamp, :auth_code => auth_code)

    return marshal(payload)
end


function unmarshal(bytes, ::Type{Tuple{TicketID, DateTime, Digest}})

    payload = unmarshal(bytes)

    ticketid = constructfrom(TicketID, payload.ticketid)
    timestamp = constructfrom(DateTime, payload.timestamp)
    auth_code = constructfrom(Digest, payload.auth_code)

    return (ticketid, timestamp, auth_code)
end



function marshal(event::Tuple{Vector{UInt8}, Digest})
    
    salt, auth_code = event
    payload = Dict(:salt => base64encode(salt), :auth_code => auth_code)

    return marshal(payload)
end


function unmarshal(bytes, ::Type{Tuple{Vector{UInt8}, Digest}})
    
    payload = unmarshal(bytes)

    salt = base64decode(payload.salt)
    auth_code = constructfrom(Digest, payload.auth_code)
    
    return (salt, auth_code)
end



function marshal(event::Tuple{TicketID, Pseudonym, Digest})
    
    id, auth_code = event
    payload = Dict(:id => id, :auth_code => auth_code)

    return marshal(payload)
end


function unmarshal(bytes, ::Type{Tuple{TicketID, Digest}})

    payload = unmarshal(bytes)
    
    @infiltrate

    id = constructfrom(Pseudonym, payload.id)
    auth_code = constructfrom(Digest, payload.auth_code)

    return (id, auth_code)
end



export marshal, unmarshal


end
