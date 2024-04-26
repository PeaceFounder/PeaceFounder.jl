module Parser

using ..Model: TicketID, Digest, Pseudonym, Signature, Seal, Membership, Proposal, Vote, ChainState, Digest, Ballot, BallotBoxState, CastReceipt, CastRecord, Model, bytes, Admission, DemeSpec, CryptoSpec, Commit, Generator, CryptoSpec, DemeSpec, HashSpec, parse_groupspec, lower_groupspec, Signer, Termination

using ..ProtocolSchema: TicketStatus, Invite, AckInclusion #, AckConsistency 
using ..BitSaver: BitMask
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

StructTypes.StructType(::Type{Signer}) = StructTypes.Struct()

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

StructTypes.StructType(::Type{Termination}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Termination}) = (:approval,)

StructTypes.StructType(::Type{BitMask}) = StructTypes.StringType()
Base.string(x::BitMask) = base64encode(convert(Vector{UInt8}, x))
StructTypes.construct(::Type{BitMask}, s::AbstractString) = convert(BitMask, base64decode(s))

function marshal(x) 
    io = IOBuffer()
    JSON3.write(io, x) 
    return take!(io)
end

marshal(io::IO, x) = JSON3.write(io, x) 


unmarshal(bytes) = JSON3.read(bytes)
unmarshal(bytes, T::DataType) = JSON3.read(bytes, T)

StructTypes.StructType(::Type{Seal}) = StructTypes.CustomStruct()
#StructTypes.lower(seal::Seal) = Dict(:id => seal.pbkey, :r => seal.sig.r, :s => seal.sig.s)

StructTypes.lower(seal::Seal) = (;id = seal.pbkey, t = seal.timestamp, r = seal.sig.r, s = seal.sig.s)
StructTypes.lowertype(::Type{Seal}) = NamedTuple{(:id, :t,  :r, :s), Tuple{String, String, BigInt, BigInt}}

function StructTypes.construct(::Type{Seal}, x)
    
    id = constructfrom(Pseudonym, x.id)
    t = constructfrom(DateTime, x.t)
    sig = Signature(x.r, x.s)

    return Seal(id, t, sig)
end


StructTypes.StructType(::Type{CryptoSpec}) = StructTypes.CustomStruct()
StructTypes.lower(crypto::CryptoSpec) = Dict(:hash => crypto.hasher, :group => lower_groupspec(crypto.group), :generator => bytes2hex(bytes(crypto.generator)))

function StructTypes.construct(::Type{CryptoSpec}, x)
    
    hasher = HashSpec(x["hash"])
    group = parse_groupspec(x["group"])
    generator = Generator(hex2bytes(x["generator"]))
    
    return CryptoSpec(hasher, group, generator)
end

StructTypes.StructType(::Type{DemeSpec}) = StructTypes.Struct()
StructTypes.omitempties(::Type{DemeSpec}) = (:timestamp, :signature)

#StructTypes.StructType(::Type{DemeSpec}) = StructTypes.Struct()
#StructTypes.omitempties(::Type{DemeSpec}) = (:cert,)

StructTypes.StructType(::Type{HashSpec}) = StructTypes.StringType()
Base.string(hasher::HashSpec) = hasher.spec
StructTypes.construct(::Type{HashSpec}, spec::AbstractString) = HashSpec(spec)


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


#StructTypes.StructType(::Type{BraidReceipt}) = StructTypes.Struct()
#StructTypes.omitempties(::Type{BraidReceipt}) = (:approval,)


### Special stroing scheme for the invite

StructTypes.StructType(::Type{Invite}) = StructTypes.StringType()

function base64encode_url(bytes::Vector{UInt8})
    str = base64encode(bytes)
    newstr = replace(str, '+'=>'-', '/'=>'_')
    return rstrip(newstr, '=')
end

function base64decode_url(str::AbstractString)
    newstr = replace(str, '-'=>'+', '_'=>'/')
    return base64decode(newstr)
end

function Base.string(invite::Invite)

    hash_str = bytes(invite.demehash) |> base64encode_url
    token_str = invite.token |> base64encode_url
    
    hash_spec = string(invite.hasher)
    
    if invite.route == URI()
        return "deme:?xt=$hash_spec:$hash_str&tk=$token_str"
    else
        return "deme:?xt=$hash_spec:$hash_str&sr=$(invite.route)&tk=$token_str"
    end
end

function StructTypes.construct(::Type{Invite}, invite_str::AbstractString) 
    
    uri = URI(invite_str)
    @assert uri.scheme == "deme"

    parameters = Dict()

    for pair in split(uri.query, '&')
        (key, value) = split(pair, '=')
        parameters[key] = value
    end
    
    route = haskey(parameters, "sr") ? URI(parameters["sr"]) : URI()
    token = base64decode_url(parameters["tk"])
    xt = URI(parameters["xt"]) 
    hasher = HashSpec(xt.scheme)
    demehash = Digest(base64decode_url(xt.path))

    return Invite(demehash, token, hasher, route)
end

marshal(invite::Invite) = Vector{UInt8}(string(invite))
unmarshal(bytes, ::Type{Invite}) = construct(Invite, String(bytes))

export marshal, unmarshal

end
