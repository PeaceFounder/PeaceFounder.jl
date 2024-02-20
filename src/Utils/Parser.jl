module Parser

using ..Model: TicketID, Digest, Pseudonym, Signature, Seal, Membership, Proposal, Vote, ChainState, Digest, Ballot, BallotBoxState, CastReceipt, CastRecord, Model, bytes, Admission, DemeSpec, CryptoSpec, Hash, TicketStatus, Commit, AckInclusion, Generator, CryptoSpec, DemeSpec, Hash, parse_groupspec, lower_groupspec, BraidReceipt, Invite
using HistoryTrees: InclusionProof, ConsistencyProof

using Dates: DateTime

using JSON3 
using StructTypes

using StructTypes: constructfrom, construct

using Base64: base64encode, base64decode
using URIs: URI


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
#unmarshal(bytes, ::Type{Pseudonym}) = construct(Pseudonym, bytes)


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


StructTypes.StructType(::Type{Membership}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Membership}) = (:approval,)


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


StructTypes.StructType(::Type{BraidReceipt}) = StructTypes.Struct()
StructTypes.omitempties(::Type{BraidReceipt}) = (:approval,)


StructTypes.StructType(::Type{Invite}) = StructTypes.CustomStruct()

StructTypes.lower(invite::Invite) = Dict(:demehash => base64encode(bytes(invite.demehash)), :token => base64encode(invite.token), :hasher => invite.hasher, :route => string(invite.route))

function StructTypes.construct(::Type{Invite}, data::Dict)

    #demehash = StructTypes.constructfrom(Digest, data["demehash"])
    demehash = Digest(base64decode(data["demehash"]))
    token = base64decode(data["token"])
    hasher = StructTypes.constructfrom(Hash, data["hasher"])
    route = URI(data["route"])
    
    return Invite(demehash, token, hasher, route)
end


export marshal, unmarshal

end
