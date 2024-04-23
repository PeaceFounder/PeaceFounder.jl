module ProtocolSchema

using StructHelpers

using Base64: base64encode
using URIs: URI
using Dates: DateTime
using HistoryTrees: HistoryTrees, InclusionProof, ConsistencyProof

using ..Model: Commit, ChainState, BallotBoxState, Transaction, CryptoSpec, HashSpec, Pseudonym, DemeSpec, CastReceipt, Proposal, Vote, TicketID, Digest, Admission, seed, bytes, digest, canonicalize
import ..Model: index, leaf, root, id, issuer, state, isbinding, verify, isconsistent, commit, hasher

using ..Model: show_string # I may need to make an Utils.jl and Components folder

function Base.show(io::IO, proof::InclusionProof)

    println(io, "InclusionProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  leaf : $(string(proof.leaf))")
    print(io, "  path : $([string(i) for i in proof.path])")

end

function Base.show(io::IO, proof::ConsistencyProof)

    println(io, "ConsistencyProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  root : $(string(proof.root))")
    print(io, "  path : $([string(i) for i in proof.path])")

end


Base.hash(proof::InclusionProof, h::UInt) = struct_hash(proof, h)
Base.hash(proof::ConsistencyProof, h::UInt) = struct_hash(proof, h)

Base.:(==)(a::InclusionProof, b::InclusionProof) = struct_equal(a, b)
Base.:(==)(a::ConsistencyProof, b::ConsistencyProof) = struct_equal(a, b)

index(proof::ConsistencyProof) = proof.index
index(proof::InclusionProof) = proof.index

#@batteries InclusionProof
#@batteries ConsistencyProof
# Note that admission is within a member as it's necessary to 

"""
    struct AckInclusion{T}
        proof::InclusionProof
        commit::Commit{T}
    end

Represents an acknowldgment from the issuer that a leaf is permanently included in the ledger. 
In case the ledger is tampered with this acknowledgement acts as sufficient proof to blame the issuer.

**Interface:** [`leaf`](@ref), [`id`](@ref), [`issuer`](@ref), [`commit`](@ref), [`index`](@ref), [`verify`](@ref)
"""
struct AckInclusion{T}
    proof::InclusionProof
    commit::Commit{T}
end

@batteries AckInclusion

function Base.show(io::IO, ack::AckInclusion)

    println(io, "AckInclusion:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end

"""
    leaf(ack::AckInclusion)

Access a leaf diggest for which the acknowledgment is made.
"""
leaf(ack::AckInclusion) = leaf(ack.proof)
id(ack::AckInclusion) = id(ack.commit)
issuer(ack::AckInclusion) = issuer(ack.commit)

"""
    index(ack::AckInclusion)::Int

Return an index at which the leaf is recorded in the ledger. To obtain the current ledger index use `index(commit(ack))`.
"""
index(ack::AckInclusion) = index(ack.proof)

"""
    commit(x)

Access a commit of an object `x`. 
"""
commit(ack::AckInclusion) = ack.commit
state(ack::AckInclusion) = state(ack.commit)


isbinding(proof::InclusionProof, commit::Commit, hasher::HashSpec) = HistoryTrees.verify(proof, root(commit), index(commit); hash = (x, y) -> digest(x, y, hasher))

#verify(ack::AckInclusion, crypto::CryptoSpec) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)
verify(ack::AckInclusion, crypto::CryptoSpec) = isbinding(ack.proof, ack.commit, crypto) && verify(commit(ack), crypto)

isbinding(ack::AckInclusion, id::Pseudonym) = issuer(ack) == id

"""
    struct AckConsistency{T}
        proof::ConsistencyProof
        commit::Commit{T}
    end

Represents an ackknowledgment from the issuer that a root is permanetly included in the ledger. This acknowledgemnt assures
that ledger up to `index(ack)` is included in the current ledger which has has index `index(commit(ack))`. This is useful in
a combination with `AckInclusion` to privatelly update it's validity rather than asking an explicit element. Also
ensures that other elements in the ledger are not being tampered with.

**Interface:** [`root`](@ref), [`id`](@ref), [`issuer`](@ref), [`commit`](@ref), [`index`](@ref), [`verify`](@ref)
"""
struct AckConsistency{T}
    proof::ConsistencyProof
    commit::Commit{T}
end

"""
    root(x::AckConsistency)

Access a root diggest for which the acknowledgment is made.
"""
root(ack::AckConsistency) = root(ack.proof)
id(ack::AckConsistency) = id(ack.commit)
issuer(ack::AckConsistency) = issuer(ack.commit)

commit(ack::AckConsistency) = ack.commit
state(ack::AckConsistency) = state(ack.commit)

isbinding(proof::ConsistencyProof, commit::Commit, hasher::HashSpec) = HistoryTrees.verify(proof, root(commit), index(commit); hash = (x, y) -> digest(x, y, hasher))

verify(ack::AckConsistency, crypto::CryptoSpec) = isbinding(ack.proof, ack.commit, crypto) && verify(commit(ack), crypto)

"""
    index(ack::AckConsistency)

Return an index for a root at which the consistency proof is made. To obtain the current ledger index use `index(commit(ack))`.

"""
index(ack::AckConsistency) = index(ack.proof)


function Base.show(io::IO, ack::AckConsistency)

    println(io, "AckConsistency:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end



function isbinding(commit::Commit{BallotBoxState}, ack::AckConsistency{BallotBoxState})
    
    issuer(commit) == issuer(ack) || return false
    state(commit).proposal == state(ack).proposal || return false    
    index(commit) == index(ack) || return false

    return true
end

isbinding(ack::AckConsistency{BallotBoxState}, commit::Commit{BallotBoxState}) = isbinding(commit, ack)


function isconsistent(commit::Commit{BallotBoxState}, ack::AckConsistency{BallotBoxState})

    seed(commit) == seed(state(ack)) || return false
    root(commit) == root(ack.proof) || return false

    return true
end

isconsistent(ack::AckConsistency{BallotBoxState}, commit::Commit{BallotBoxState}) = isconsistent(commit, ack)



"""
    isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::CryptoSpec)

A generic method checking whether transaction is included in the braidchain.
"""
isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::CryptoSpec) = digest(record, crypto) == leaf(ack)

isbinding(record::Transaction, ack::AckInclusion{ChainState}, hasher::HashSpec) = digest(record, hasher) == leaf(ack)
isbinding(ack::AckInclusion{ChainState}, record::Transaction, hasher::HashSpec) = isbinding(record, ack, hasher)


isbinding(ack::AckInclusion{ChainState}, id::Pseudonym) = issuer(ack) == id

isbinding(ack::AckInclusion{ChainState}, deme::DemeSpec) = issuer(ack) == deme.recorder

isbinding(record::Transaction, ack::AckInclusion{ChainState}, deme::DemeSpec) = isbinding(ack, deme) && isbinding(record, ack, hasher(deme))

"""
    isbinding(receipt::CastReceipt, ack::AckInclusion, hasher::HashSpec)::Bool

Check that cast receipt is binding to received inclusion acknowledgment.
"""
isbinding(receipt::CastReceipt, ack::AckInclusion, hasher::HashSpec) = digest(receipt, hasher) == leaf(ack)



# The client does not need to depend on BallotBoxController!

"""
    struct CastAck
        receipt::CastReceipt
        ack::AckInclusion{BallotBoxState}
    end

Represents a reply to a voter when a vote have been included in the ballotbox ledger. Contains a receipt
and inlcusion acknowledgment. In future would also include a blind signature in the reply for a proof of
participation. To receive this reply (with a blind signature in the future) a voter needs to send a vote
 which is concealed during ellections and thus tagging votes with blind signatures from reply to monitor 
revoting would be as hard as monitoring the submitted votes.
"""
struct CastAck
    receipt::CastReceipt
    alias::Int
    ack::AckInclusion{BallotBoxState}
end

id(ack::CastAck) = id(ack.ack)
index(ack::CastAck) = index(ack.ack)

"""
    verify(ack::CastAck, crypto::CryptoSpec)::Bool

Verify the cast acknowledgment cryptographic signature. 
"""
function verify(ack::CastAck, crypto::CryptoSpec)
    isbinding(ack.receipt, ack.ack, hasher(crypto)) || return false
    return verify(ack.ack, crypto)
end

"""
    isbinding(ack::CastAck, proposal::Proposal, hasher::HashSpec)::Bool

Check that acknowledgment is legitimate meaning that it is issued by a collector listed in the proposal.
"""
isbinding(ack::CastAck, proposal::Proposal, hasher::HashSpec) = isbinding(ack.ack, proposal, hasher)

isbinding(ack::AckInclusion{BallotBoxState}, proposal::Proposal, hasher::HashSpec) = issuer(ack) == proposal.collector && state(ack).proposal == digest(proposal, hasher)

isbinding(ack::AckConsistency{BallotBoxState}, proposal::Proposal, hasher::HashSpec) = issuer(ack) == proposal.collector && state(ack).proposal == digest(proposal, hasher)

isbinding(ack::CastAck, vote::Vote, hasher::HashSpec) = isbinding(ack.receipt, vote, hasher)

isbinding(ack::CastAck, commit::Commit{BallotBoxState}) = isbinding(ack.ack, commit)

"""
    commit(ack::CastAck)

Return a commit from a `CastAck`.
"""
commit(ack::CastAck) = commit(ack.ack)

function Base.show(io::IO, ack::CastAck)

    println(io, "CastAck:")
    println(io, show_string(ack.receipt))
    println(io, show_string(ack.ack))

end

# The tracking_code could be delivered asymmetrically encrypted to the voter after cast so the observer of communication could 
# not derive it themselves. Thus, it needs to stand within this module for such feature
tracking_code(vote::Vote, hasher::HashSpec; nlen = 5) = hasher(UInt8[0, canonicalize(vote)...])[1:nlen]
tracking_code(vote::Vote, spec; nlen = 5) = tracking_code(vote, hasher(spec); nlen)


# Could also contain a BlameProof type definition which client constructs in case of inconsistency


struct Invite
    demehash::Digest
    token::Vector{UInt8} 
    hasher::HashSpec # HashSpecSpec
    route::URI
end

Base.:(==)(x::Invite, y::Invite) = x.demehash == y.demehash && x.token == y.token && x.hasher == y.hasher && x.route == y.route

Base.show(io::IO, invite::Invite) = print(io, string(invite))

# This gives a nasty error for some reason when CryptoGroups are imported.
#@batteries Invite

isbinding(spec::DemeSpec, invite::Invite) = digest(spec, invite.hasher) == invite.demehash

# Parsing to string and back

hasher(invite::Invite) = invite.hasher


tokenid(token::Vector{UInt8}, hash::HashSpec) = digest(token, hash) |> bytes |> base64encode


"""
struct TicketStatus
    ticketid::TicketID
    timestamp::DateTime
    admission::Union{Nothing, Admission}
end
    
Represents a public state of a ticket. See [`isadmitted`](@ref) method. 
"""
struct TicketStatus
    ticketid::TicketID
    timestamp::DateTime
    admission::Union{Nothing, Admission}
end


"""
    isadmitted(status::TicketStatus)

Check whether ticket is addmitted. 
"""
isadmitted(status::TicketStatus) = !isnothing(status.admission)


end
