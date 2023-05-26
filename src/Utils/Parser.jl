module Parser

using ..Model: TicketID, Digest, Pseudonym, Signature, Seal, Member, Proposal, Vote, ChainState, Digest, Ballot, BallotBoxState, NonceCommitment, Lot, CastReceipt, CastRecord, Model, bytes, Admission, DemeSpec, CryptoSpec, Hash, TicketStatus, Commit, AckInclusion, Generator, CryptoSpec, DemeSpec, Hash, parse_groupspec, lower_groupspec, BraidWork
using HistoryTrees: InclusionProof, ConsistencyProof

using Dates: DateTime

using JSON3 
using StructTypes

using StructTypes: constructfrom, construct

using Base64: base64encode, base64decode


# Should be removed when canonicalization methods will be implemented.
Model.canonicalize(x) = marshal(x)


# Needed for canonicalize method
StructTypes.StructType(::Type{Signature}) = StructTypes.Struct()


StructTypes.StructType(::Type{Proposal}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Proposal}) = (:approval,)

StructTypes.StructType(::Type{Vote}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Vote}) = (:approval,)

StructTypes.StructType(::Type{Ballot}) = StructTypes.Struct()

StructTypes.StructType(::Type{BallotBoxState}) = StructTypes.Struct()
StructTypes.omitempties(::Type{BallotBoxState}) = (:tally, :view)

StructTypes.StructType(::Type{NonceCommitment}) = StructTypes.Struct()

StructTypes.StructType(::Type{Lot}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Lot}) = (:pulse,)

StructTypes.StructType(::Type{CastReceipt}) = StructTypes.Struct()
StructTypes.StructType(::Type{CastRecord}) = StructTypes.Struct()


StructTypes.StructType(::Type{TicketID}) = StructTypes.StringType()
Base.string(ticketid::TicketID) = bytes2hex(bytes(ticketid))
StructTypes.construct(::Type{TicketID}, s::AbstractString) = TicketID(hex2bytes(s))


StructTypes.StructType(::Type{Digest}) = StructTypes.StringType()
Base.string(x::Digest) = bytes2hex(bytes(x))
StructTypes.construct(::Type{Digest}, s::AbstractString) = Digest(hex2bytes(s))


StructTypes.StructType(::Type{Pseudonym}) = StructTypes.StringType()
Base.string(x::Pseudonym) = bytes2hex(bytes(x))
StructTypes.construct(::Type{Pseudonym}, s::AbstractString) = Pseudonym(hex2bytes(s))


StructTypes.StructType(::Type{Generator}) = StructTypes.StringType()
Base.string(x::Generator) = bytes2hex(bytes(x))
StructTypes.construct(::Type{Generator}, s::AbstractString) = Generator(hex2bytes(s))


StructTypes.StructType(::Type{Admission}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Admission}) = (:approval,)


function marshal(x) 
    io = IOBuffer()
    JSON3.write(io, x) 
    return take!(io)
end

unmarshal(bytes) = JSON3.read(bytes)

unmarshal(bytes, T::DataType) = JSON3.read(bytes, T)


StructTypes.StructType(::Type{Seal}) = StructTypes.CustomStruct()
#StructTypes.lower(seal::Seal) = Dict(:id => seal.pbkey, :r => seal.sig.r, :s => seal.sig.s)

StructTypes.lower(seal::Seal) = (;id = seal.pbkey, r = seal.sig.r, s = seal.sig.s)
StructTypes.lowertype(::Type{Seal}) = NamedTuple{(:id, :r, :s), Tuple{String, BigInt, BigInt}}

function StructTypes.construct(::Type{Seal}, x)
    
    id = constructfrom(Pseudonym, x.id)
    sig = Signature(x.r, x.s)

    return Seal(id, sig)
end


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


function marshal(event::Tuple{Vector{UInt8}, Vector{UInt8}, Digest})
    
    metadata, salt, auth_code = event
    payload = Dict(:metadata => bytes2hex(metadata), :salt => bytes2hex(salt), :auth_code => auth_code)

    return marshal(payload)
end

function unmarshal(bytes, ::Type{Tuple{Vector{UInt8}, Vector{UInt8}, Digest}})
    
    payload = unmarshal(bytes)

    metadata = hex2bytes(payload.metadata)
    salt = hex2bytes(payload.salt)
    auth_code = constructfrom(Digest, payload.auth_code)
    
    return (metadata, salt, auth_code)
end



function marshal(event::Tuple{TicketID, Pseudonym, Digest})
    
    id, auth_code = event
    payload = Dict(:id => id, :auth_code => auth_code)

    return marshal(payload)
end


function unmarshal(bytes, ::Type{Tuple{TicketID, Digest}})

    payload = unmarshal(bytes)
    
    id = constructfrom(Pseudonym, payload.id)
    auth_code = constructfrom(Digest, payload.auth_code)

    return (id, auth_code)
end


StructTypes.StructType(::Type{CryptoSpec}) = StructTypes.CustomStruct()
StructTypes.lower(crypto::CryptoSpec) = Dict(:hash => crypto.hasher, :group => lower_groupspec(crypto.group), :generator => bytes2hex(bytes(crypto.generator)))

function StructTypes.construct(::Type{CryptoSpec}, x)
    
    hasher = Hash(x["hash"])
    group = parse_groupspec(x["group"])
    generator = Generator(hex2bytes(x["generator"]))

    return CryptoSpec(hasher, group, generator)
end


StructTypes.StructType(::Type{DemeSpec}) = StructTypes.Struct()
StructTypes.omitempties(::Type{DemeSpec}) = (:timestamp, :signature)

#StructTypes.StructType(::Type{DemeSpec}) = StructTypes.Struct()
#StructTypes.omitempties(::Type{DemeSpec}) = (:cert,)

StructTypes.StructType(::Type{Hash}) = StructTypes.StringType()
Base.string(hasher::Hash) = hasher.spec
StructTypes.construct(::Type{Hash}, spec::AbstractString) = Hash(spec)


StructTypes.StructType(::Type{TicketStatus}) = StructTypes.Struct()
StructTypes.omitempties(::Type{TicketStatus}) = (:admission,)


StructTypes.StructType(::Type{Member}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Member}) = (:approval,)


StructTypes.StructType(::Type{Commit}) = StructTypes.Struct()
StructTypes.StructType(::Type{AckInclusion}) = StructTypes.Struct()


StructTypes.StructType(::Type{ChainState}) = StructTypes.Struct()


StructTypes.StructType(::Type{InclusionProof}) = StructTypes.CustomStruct()
StructTypes.lower(proof::InclusionProof) = Dict(:index => proof.index, :leaf => proof.leaf, :path => proof.path)

function StructTypes.construct(::Type{InclusionProof}, event)

    index = event["index"]
    leaf = Digest(hex2bytes(event["leaf"]))
    path = Digest[Digest(hex2bytes(i)) for i in event["path"]]

    return InclusionProof(path, index, leaf)
end


StructTypes.StructType(::Type{ConsistencyProof}) = StructTypes.CustomStruct()
StructTypes.lower(proof::ConsistencyProof) = Dict(:index => proof.index, :root => proof.root, :path => proof.path)

function StructTypes.construct(::Type{ConsistencyProof}, event)

    index = event["index"]
    root = Digest(hex2bytes(event["root"]))
    path = Digest[Digest(hex2bytes(i)) for i in event["path"]]

    return ConsistencyProof(path, index, root)
end


export marshal, unmarshal


StructTypes.StructType(::Type{BraidWork}) = StructTypes.Struct()
StructTypes.omitempties(::Type{BraidWork}) = (:approval,)



end
