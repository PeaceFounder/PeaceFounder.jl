"""
One to one mapping from a value to byte vector. Necessary to uniquelly hash an object.
"""
function canonicalize(m::Member)
    io = IOBuffer()
    JSON3.write(io, m)
    return take!(io)
end

function canonicalize(v::Vote)
    io = IOBuffer()
    JSON3.write(io, v)
    return take!(io)
end

function canonicalize(p::Proposal)
    io = IOBuffer()
    JSON3.write(io, p)
    return take!(io)
end


function canonicalize(state::ChainState)
    io = IOBuffer()
    JSON3.write(io, state)
    return take!(io)
end

function canonicalize(state::BallotBoxState)
    io = IOBuffer()
    JSON3.write(io, state)
    return take!(io)
end

function canonicalize(admission::Admission)
    io = IOBuffer()
    JSON3.write(io, admission)
    return take!(io)
end


function canonicalize(promise::NonceCommitment)
    io = IOBuffer()
    JSON3.write(io, promise)
    return take!(io)
end


function canonicalize(lot::Lot)
    io = IOBuffer()
    JSON3.write(io, lot)
    return take!(io)
end



digest(vote::Vote, hasher::Hash) = digest(canonicalize(vote), hasher)

digest(proposal::Proposal, hasher::Hash) = digest(canonicalize(proposal), hasher)

function body(proposal::Proposal)
    proposal = @set proposal.approval = nothing
    return proposal
end


body(member::Member) = @set member.approval = nothing

function sign(member::Member, signer::Signer)
    @assert id(signer) == id(member)
    return sign(canonicalize(body(member)), signer)
end


# The body method is actually pretty interesting 
body(admission::Admission) = @set admission.approval = nothing

# canonicalize, seal, verify shall be put in a serate file
function seal(admission::Admission, signer::Signer)

    bytes = canonicalize(body(admission))
    
    return seal(bytes, signer)
end


function seal(state::ChainState, signer::Signer)

    bytes = canonicalize(state)

    return seal(bytes, signer)
end


verify(state::ChainState, seal::Seal, crypto::Crypto) = verify(canonicalize(state), seal, crypto)


function seal(state::BallotBoxState, signer::Signer)

    bytes = canonicalize(state)

    return seal(bytes, signer)
end

verify(state::BallotBoxState, seal::Seal, crypto::Crypto) = verify(canonicalize(state), seal, crypto)


body(vote::Vote) = @set vote.approval = nothing


function seal(vote::Vote, generator::Vector{UInt8}, signer::Signer)

    @assert vote.seq == seq(signer, vote.proposal) + 1

    bytes = canonicalize(body(vote))
    
    return seal(bytes, generator, signer)
end


function verify(vote::Vote, generator::Vector{UInt8}, crypto::Crypto)
    
    bytes = canonicalize(body(vote))

    return verify(bytes, vote.approval, generator, crypto)
end



function verify(admission::Admission, crypto::Crypto)

    bytes = canonicalize(admission)
    
    return verify(bytes, admission.approval, crypto)
end


function verify(member::Member, crypto::Crypto)
    return verify(member.admission, crypto) && verify(canonicalize(body(member)), id(member.admission), member.approval, crypto)
end


function approve(proposal::Proposal, signer::Signer)
    bytes = canonicalize(body(proposal))
    approval = seal(bytes, signer)
    proposal = @set proposal.approval = approval
    return proposal
end


function verify(proposal::Proposal, crypto::Crypto)
    
    bytes = canonicalize(body(proposal))

    return verify(bytes, proposal.approval, crypto)
end






#hash(bytes::Vector{UInt8}) = Nettle.digest("SHA3_256", bytes)
function digest(data::Vector{UInt8}, hasher::Hash)
    return Digest(Nettle.digest("SHA3_256", data))
end

function digest(data::Transaction, hasher::Hash)
    bytes = canonicalize(data)
    return digest(bytes, hasher)
end

function digest(x::Digest, y::Digest, hasher::Hash)
    return digest(UInt8[x.data..., y.data...], hasher)
end



# Needed for canonicalize method
StructTypes.StructType(::Type{Pseudonym}) = StructTypes.Struct()
StructTypes.StructType(::Type{Signature}) = StructTypes.Struct()
StructTypes.StructType(::Type{Seal}) = StructTypes.Struct()

StructTypes.StructType(::Type{Member}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Member}) = (:approval, :PoK)

StructTypes.StructType(::Type{Proposal}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Proposal}) = (:approval,)

StructTypes.StructType(::Type{Vote}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Vote}) = (:approval,)

StructTypes.StructType(::Type{ChainState}) = StructTypes.Struct()
StructTypes.StructType(::Type{Digest}) = StructTypes.Struct()

StructTypes.StructType(::Type{Ballot}) = StructTypes.Struct()

StructTypes.StructType(::Type{BallotBoxState}) = StructTypes.Struct()
StructTypes.omitempties(::Type{BallotBoxState}) = (:tally,)

StructTypes.StructType(::Type{NonceCommitment}) = StructTypes.Struct()

StructTypes.StructType(::Type{Lot}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Lot}) = (:pulse,)




