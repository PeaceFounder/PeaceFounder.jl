"""
ToDo: a well specified encoding is essential here. Binary tree encoding may suffice here. More fancy approach would be to use a DER encoding. Meanwhile JSON shall be used.
"""
function canonicalize end

# digest could have a generic method with canonicalize. 
digest(::Nothing, hasher::HashSpec) = error("Can't digest nothing")

digest(vote::Vote, hasher::HashSpec) = digest(canonicalize(vote), hasher)

digest(proposal::Proposal, hasher::HashSpec) = digest(canonicalize(proposal), hasher)

digest(record::CastRecord, hasher::HashSpec) = digest(receipt(record, hasher), hasher) # exception

digest(receipt::CastReceipt, hasher::HashSpec) = digest(canonicalize(receipt), hasher)

digest(spec::DemeSpec, hasher::HashSpec) = digest(canonicalize(spec), hasher)

digest(pseudonym::Pseudonym, hasher::HashSpec) = digest(bytes(pseudonym), hasher)

digest(seal::Seal, hasher::HashSpec) = digest(canonicalize(seal), hasher)


function body(proposal::Proposal)
    proposal = @set proposal.approval = nothing
    return proposal
end


body(member::Membership) = @set member.approval = nothing

function sign(member::Membership, signer::Signer)
    @assert id(signer) == id(member)
    return sign(canonicalize(body(member)), signer)
end


# The body method is actually pretty interesting 
body(admission::Admission) = @set admission.seal = nothing

body(spec::DemeSpec) = @set spec.seal = nothing

function approve(spec::DemeSpec, signer::Signer)

    spec = @set spec.seal = nothing
    spec = @set spec.seal = seal(canonicalize(spec), signer)

    return spec
end

approve(signer::Signer) = x -> approve(x, signer) # late evaluation


#verify(spec::DemeSpec, crypto::CryptoSpec) = verify(canonicalize(@set spec.seal = nothing), spec.guardian, spec.signature, crypto)
verify(spec::DemeSpec, crypto::CryptoSpec) = verify(canonicalize(@set spec.seal = nothing), spec.seal, crypto)



# canonicalize, seal, verify shall be put in a serate file
function seal(admission::Admission, signer::Signer)

    bytes = canonicalize(body(admission))
    
    return seal(bytes, signer)
end


function seal(state::ChainState, signer::Signer)

    bytes = canonicalize(state)

    return seal(bytes, signer)
end


verify(state::ChainState, seal::Seal, crypto::CryptoSpec) = verify(canonicalize(state), seal, crypto)


function seal(state::BallotBoxState, signer::Signer)

    bytes = canonicalize(state)

    return seal(bytes, signer)
end

verify(state::BallotBoxState, seal::Seal, crypto::CryptoSpec) = verify(canonicalize(state), seal, crypto)


body(vote::Vote) = @set vote.seal = nothing


# Should not use this approach
function seal(vote::Vote, generator::Generator, signer::Signer; timestamp::Union{DateTime} = nothing)

    #@assert vote.seq == seq(signer, vote.proposal) + 1

    bytes = canonicalize(body(vote))
    
    return seal(bytes, generator, signer; timestamp)
end


function verify(vote::Vote, generator::Generator, crypto::CryptoSpec)
    
    bytes = canonicalize(body(vote))

    return verify(bytes, vote.seal, generator, crypto)
end



function verify(admission::Admission, crypto::CryptoSpec)

    bytes = canonicalize(body(admission))
    
    return verify(bytes, admission.seal, crypto)
end


function verify(member::Membership, crypto::CryptoSpec)
    return verify(member.admission, crypto) && verify(canonicalize(body(member)), id(member.admission), member.approval, crypto)
end


function approve(proposal::Proposal, signer::Signer)
    bytes = canonicalize(body(proposal))
    approval = seal(bytes, signer)
    proposal = @set proposal.approval = approval
    return proposal
end


function verify(proposal::Proposal, crypto::CryptoSpec)
    
    bytes = canonicalize(body(proposal))

    return verify(bytes, proposal.approval, crypto)
end


function digest(record::BraidReceipt, hasher::HashSpec)

    braid_hash = digest(record.braid, hasher)
    spec_hash = digest(record.producer, hasher)
    seal_hash = digest(record.approval, hasher)

    return digest(UInt8[bytes(braid_hash)..., bytes(spec_hash)..., bytes(seal_hash)...], hasher)
end

body(record::BraidReceipt) = record.braid

digest(braid::ShuffleProofs.Simulator, hasher::HashSpec) = Digest(ShuffleProofs.digest(braid, hasher))


# body(braidwork::BraidReceipt) = @set braidwork.approval = nothing

function seal(braidwork::BraidReceipt, signer::Signer)

    _digest = digest(braidwork.braid, hasher(signer))

    #bytes = canonicalize(body(braidwork))

    return seal(bytes(_digest), signer) # A timestamp is added in front thus it does not do a double hashing at all here.
end


# function verify(braidwork::BraidReceipt, crypto::CryptoSpec)
    
#     _digest = digest(braidwork, signer.crypto)

#     #bytes = canonicalize(body(braidwork))
    
#     return verify(_digest, braidwork.approval, crypto)
# end

# verify(braidwork::BraidReceipt) = verify(braidwork, braidwork.producer.crypto)


function digest(data::Transaction, hasher::HashSpec)
    bytes = canonicalize(data)
    return digest(bytes, hasher)
end

function digest(x::Digest, y::Digest, hasher::HashSpec)
    return digest(UInt8[x.data..., y.data...], hasher)
end
