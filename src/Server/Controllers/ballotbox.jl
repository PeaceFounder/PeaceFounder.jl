#module BallotBoxController

using Dates: Dates, DateTime
using Base: UUID
using HistoryTrees: HistoryTree
using ..StaticSets: StaticSet, findindex

using ..Core.Model: Proposal, Pseudonym, Digest, CryptoSpec, DemeSpec, Vote, CastRecord, BallotBoxState, Signer, Commit, BallotBoxLedger, selections
using ..Core.ProtocolSchema: AckInclusion, AckConsistency, CastAck
import ..Core.Model: uuid, voters, seed, receipt, tally, tallyview, istallied, isbinding


#import ..LedgerInterface: record!, commit!, ack_leaf, ack_root, commit_index, reset_tree!, root, commit, select, state, leaf


"""
    mutable struct BallotBox
        proposal::Proposal
        voters::Set{Pseudonym} # better than members
        collector::Pseudonym
        seed::Union{Digest, Nothing}
        crypto::CryptoSpec # on the other hand the inclusion of a vote should be binding enough as it includes proposal hash.
        queue::Vector{Vote}
        ledger::Vector{CastRecord}
        tree::HistoryTree
        commit::Union{Commit{BallotBoxState}, Nothing}
    end
    
Represents a ballot box for a proposal. Contains `proposal`, a set of eligiable `voters` a `collector` who collects the votes and a `seed` which is selected at random when the voting starts. `queue` contains a list of valid votes which yet to be comitted to a `ledger`. A history `tree` is built on leafs of ledger's receipts (see a [`receipt`](@ref) method). A `commit` contains a collector seal on the current ballotbox state. 

**Interface:** [`reset_tree!`](@ref), [`generator`](@ref), [`uuid`](@ref), [`members`](@ref), [`ledger`](@ref), [`spine`](@ref), [`index`](@ref), [`seed`](@ref), [`leaf`](@ref), [`root`](@ref), [`record`](@ref), [`receipt`](@ref), [`commit`](@ref), [`tally`](@ref), [`set_seed!`](@ref), [`ack_leaf`](@ref), [`ack_root`](@ref), [`ack_cast`](@ref), [`commit_index`](@ref), [`commit_state`](@ref), [`push!`](@ref), [`state`](@ref), [`validate`](@ref), [`record!`](@ref), [`commit!`](@ref)
"""
mutable struct BallotBox
    ledger::BallotBoxLedger
    #proposal::Proposal
    voters::StaticSet{Pseudonym} # Ordering is necessary for supporting alias encoding and thus ordinary Set could not be used
    collector::Pseudonym
    seed::Union{Digest, Nothing}
    #crypto::CryptoSpec # on the other hand the inclusion of a vote should be binding enough as it includes proposal hash.
    queue::Vector{Vote}
    #ledger::Vector{CastRecord}
    tree::HistoryTree
    commit::Union{Commit{BallotBoxState}, Nothing}
end


#BallotBox(proposal::Proposal, voters::Vector{Pseudonym}, collector::Pseudonym, crypto::CryptoSpec) = BallotBox(BallotBoxLedger(CastRecord[], proposal, spec), StaticSet(voters), collector, nothing, crypto, Vote[], CastRecord[], HistoryTree(Digest, hasher(crypto)), nothing)

BallotBox(proposal::Proposal, voters::Vector{Pseudonym}, spec::DemeSpec, collector::Pseudonym) = BallotBox(BallotBoxLedger(CastRecord[], proposal, spec), StaticSet(voters), collector, nothing, Vote[], HistoryTree(Digest, hasher(spec)), nothing)

BallotBox(proposal::Proposal, voters::Vector{Pseudonym}, spec::DemeSpec) = BallotBox(proposal, voters, spec, spec.collector)


function Base.show(io::IO, ballotbox::BallotBox)

    println(io, "BallotBox:")
    println(io, "  voters : $(length(ballotbox.ledger)) entries")
    println(io, "  seed : $(string(ballotbox.seed))")
    println(io, "  queue : $(length(ballotbox.queue)) uncommited entries")
    println(io, show_string(ballotbox.ledger.proposal))
    println(io, "")

    print_vector(io, ballotbox.ledger.records)
    
    println(io, "")
    println(io, show_string(ballotbox.commit))

end

"""
    reset_tree!(ledger::BallotBox)

Recompute history tree root and cache from the elements in the ledger. This is a useful
for loading the ledger all at once.  
"""
function reset_tree!(ballotbox::BallotBox)

    d = Digest[digest(i, hasher(ballotbox.ledger.spec)) for i in ballotbox.ledger]
    tree = HistoryTree(d, hasher(ballotbox.ledger.spec))

    ballotbox.tree = tree

    return
end

"""
    generator(ledger::BallotBox)

Return a relative generator which members use to sign votes anchored by the proposal.
"""
generator(ballotbox::BallotBox) = generator(ballotbox.ledger)

"""
    uuid(ledger::BallotBox)

Return a UUID of the proposal.
"""
uuid(ballotbox::BallotBox) = uuid(ballotbox.ledger)

"""
    members(ledger::BallotBox)

Return a list of member pseudonyms with which members authetificate their votes.
"""
voters(ballotbox::BallotBox) = ballotbox.voters

"""
    ledger(ballotbox::BallotBox)::Vector{CastRecord}

Return all records from a ballotbox ledger.
"""
ledger(ballotbox::BallotBox) = ballotbox.ledger

"""
    spine(ledger::BallotBox)::Vector{Digest}

Return a history tree leaf vector.
"""
spine(ballotbox::BallotBox) = ballotbox.tree.d # 

# TODO: consider using a bare length instead
"""
    length(ledger::BallotBox)

Return a total length of the ledger including uncommited records in the queue.
"""
Base.length(ballotbox::BallotBox) = length(ledger(ballotbox)) + length(ballotbox.queue)

"""
    index(ledger::BallotBox)

Return the current index of the ledger. See also [`length`](@ref).
"""
index(ballotbox::BallotBox) = length(ledger(ballotbox)) # perhaps commit_index instead

"""
    seed(ledger::BallotBox)::Union{Digest, Nothing}

Return a random selected seed used in the voting.
"""
seed(ballotbox::BallotBox) = ballotbox.seed

"""
    leaf(ledger::BallotBox, N::Int)::Digest

Return a record digest used to form a history tree.
"""
leaf(ballotbox::BallotBox, N::Int) = leaf(ballotbox.tree, N)

"""
    root(ledger::BallotBox[, N::Int])::Digest

Calculate a root for history tree at given index `N`. If index is not specified
returns the current value.
"""
root(ballotbox::BallotBox, N::Int) = root(ballotbox.tree, N)
root(ballotbox::BallotBox) = root(ballotbox.tree)

"""
    record(ledger::BallotBox, index::Int)::CastRecord

Return a ledger record at provided `index`.
"""
record(ballotbox::BallotBox, N::Int) = ledger(ballotbox)[N]

"""
    receipt(ledger::BallotBox, index::Int)::CastReceipt

Return a receipt for a ledger element.
"""
receipt(ballotbox::BallotBox, N::Int) = receipt(ballotbox[N], ballotbox.ledger.spec)

"""
    commit(ledger::BallotBox)

Return a commit for the ballotbox ledger.
"""
commit(ballotbox::BallotBox) = !isnothing(ballotbox.commit) ? ballotbox.commit : error("ballotbox had not been commited yet")

tally(ballotbox::BallotBox) = tally(ledger(ballotbox))

tallyview(ballotbox::BallotBox) = tallyview(ballotbox.ledger)

istallied(ballotbox::BallotBox) = istallied(ballotbox.commit)

"""
    set_seed!(ledger::BallotBox, seed::Digest)

Set's a seed of the ballotbox.
"""
set_seed!(ballotbox::BallotBox, seed::Digest) = ballotbox.seed = seed;


"""
    ack_leaf(ledger::BallotBox, index::Int)::AckInclusion

Compute an inclusion proof `::AckInclusion` for record element at given `index`.
"""
function ack_leaf(ballotbox::BallotBox, index::Int) 

    @assert commit_index(ballotbox) >= index

    proof = InclusionProof(ballotbox.tree, index)

    return AckInclusion(proof, commit(ballotbox))
end


#isbinding(vote::Vote, ack::AckInclusion{BallotBoxState}, crypto::Crypto) = digest(vote, crypto) == leaf(ack)

"""
    isbinding(vote::Vote, ack::CastAck, hasher)

Check whether acknowledgment is bound to the provided vote.
"""
isbinding(vote::Vote, ack::CastAck, crypto::CryptoSpec) = digest(vote, crypto) == ack.receipt.vote


"""
    ack_root(ledger::BallotBox, index::Int)::AckConsistency

Compute a history tree consistency proof at `index`. 
"""
function ack_root(ballotbox::BallotBox, index::Int) 

    @assert commit_index(ballotbox) >= index

    proof = ConsistencyProof(ballotbox.tree, index)

    return AckConsistency(proof, commit(ballotbox))
end

"""
    ack_cast(ledger::BallotBox, index::Int)::CastAck

Compute an acknowledgment for record inclusion at `index`.
"""
function ack_cast(ballotbox::BallotBox, N::Int)
    
    ack = ack_leaf(ballotbox, N)
    _receipt = receipt(ballotbox, N)

    return CastAck(_receipt, ack)    
end

"""
    commit_index(ledger::BallotBox)::Union{Index, Nothing}

Index at which commit is issued. See also [`length`](@ref) and [`index`](@ref)
"""
commit_index(ballotbox::BallotBox) = index(commit(ballotbox))

"""
    commit_state(ledger::BallotBox)

Return a committed state for a ballotbox ledger.
"""
commit_state(ballotbox::BallotBox) = state(commit(ballotbox))

"""
    push!(ledger::BallotBox, record::CastRecord)

Push a `record` to the `ledger` bypassing integrity checks. Used when loading the ledger
from a trusted source such as local disk or an archive with a signed root cheksum.
"""
function Base.push!(ballotbox::BallotBox, record::CastRecord) 
    
    push!(ballotbox.tree, digest(record, ballotbox.ledger.spec))
    push!(ballotbox.ledger, record)

    return
end


Base.getindex(bbox::BallotBox, index::Int) = bbox.ledger[index]

 using Infiltrator


function state(bbox::BallotBox; with_tally::Union{Nothing, Bool} = nothing)

    # nothing follows the current state
    if isnothing(with_tally)
        if isnothing(bbox.commit) || isnothing(bbox.commit.state.tally)
            with_tally = false
        else
            with_tally = true
        end
    end

    return state(ledger(bbox); seed = bbox.seed, root = root(bbox), with_tally)
end

function get_dublicate_index(ballotbox::BallotBox, vote::Vote)

    N = findfirst(r -> r.vote == vote, ledger(ballotbox))
    !isnothing(N) && return N

    M = findfirst(==(vote), ballotbox.queue)
    !isnothing(M) && return M + length(ledger(ballotbox))
    
    return
end


"""
    validate(ledger::BallotBox, vote::Vote)

Check that vote can be included in the ballotbox. Is well formed, signed by a member pseudonym
and cryptographic signature is valid. Raises error if either of checks fail.
"""
function validate(ballotbox::BallotBox, vote::Vote)
    
    # Poorly formed votes are interesting
    # @assert isconsistent(vote.selection, ballotbox.proposal.ballot)
    @assert isbinding(vote, ballotbox.ledger.proposal, ballotbox.ledger.spec) # isbinding(proposal(ballotbox), vote, crypto) 
    #@assert pseudonym(vote) in members(ballotbox)
    @assert pseudonym(vote) in voters(ballotbox)

    @assert verify(vote, generator(ballotbox), ballotbox.ledger.spec)

    return
end


"""
    record!(ledger::BallotBox, vote::Vote)

Check the vote for validity and pushes it to the queue. Returns an index `N`
at which the vote will be recorded in the ledger. See also [`push!`](@ref)
"""
function record!(ballotbox::BallotBox, vote::Vote)

    @assert !isnothing(ballotbox.commit) "The BallotBox is not yet initialized. Add a seed and make the first commit."
    # Note that the seed equality is not verified because it is useful for tracking issues

    N = get_dublicate_index(ballotbox, vote)
    isnothing(N) || return N
    
    validate(ballotbox, vote)

    push!(ballotbox.queue, vote)

    N = length(ballotbox) # here it is important to have a proper length of the data!
    
    return N
end

"""
    record!(ledger::BallotBox, record::CastRecord)

Check the vote in the record for validity and include that in the ledger directly bypassing queue. 
This method is useful for replaying and debugging ballotbox ledger state changes. 
See also [`record!`](@ref)
"""
function record!(ballotbox::BallotBox, record::CastRecord)

    @assert length(ballotbox.queue) == 0 "BallotBox has uncommited votes."

    (; vote ) = record

    N = get_dublicate_index(ballotbox, vote)
    isnothing(N) || return N

    validate(ballotbox, vote)

    push!(ballotbox, record)

    N = length(ballotbox) # here it is important to have a proper length of the data!
    
    return N
end

"""
    commit!(ledger::BallotBox[, timestamp::DataTime], signer::Signer; with_tally=nothing)

Flushes ballotbox ledger's queue and creates a commit for a current ballotbox ledger state with provided `timestamp` and `signer`. A keyword argument `with_tally` has three values `true|false` to include or exclude a tally from a commited state and `nothing` which uses a previous commit preference.
"""
function commit!(ballotbox::BallotBox, timestamp::DateTime, signer::Signer; with_tally::Union{Nothing, Bool} = nothing)

    # while commit! no changes to ballotbox allowed. It's up to user to put locks in place.

    for vote in ballotbox.queue

        # an ideal place to form a blind signature on the user's request.
        record = CastRecord(vote, timestamp)
        push!(ballotbox, record)
        
    end

    resize!(ballotbox.queue, 0)

    _state = state(ballotbox; with_tally)
    ballotbox.commit = Commit(_state, seal(_state, signer))

    return
end

commit!(ballotbox::BallotBox, signer::Signer; with_tally::Union{Nothing, Bool} = nothing) = commit!(ballotbox, Dates.now(), signer; with_tally)


"""
    struct PollingStation
        halls::Vector{BallotBox}
        crypto::CryptoSpec
    end

Represents a pooling station which hosts ballotbox ledgers for every proposal collector manages. 

**Interface:** [`add!`](@ref), [`ballotbox`](@ref), [`record!`](@ref), [`commit!`](@ref), [`commit`](@ref), [`ack_leaf`](@ref), [`ack_root`](@ref), [`ack_cast`](@ref), [`record`](@ref), [`receipt`](@ref), [`spine`](@ref), [`ledger`](@ref), [`tally`](@ref), [`set_seed!`](@ref)
"""
struct PollingStation
    halls::Vector{BallotBox}
    #crypto::CryptoSpec
end

#PollingStation(crypto::CryptoSpec) = PollingStation(BallotBox[], crypto)
PollingStation() = PollingStation(BallotBox[])


function Base.show(io::IO, station::PollingStation)
    
    println(io, "PollingStation:")
    println(io, "")

    for i in station.halls
        println(io, show_string(i.proposal))
    end

end

"""
    add!(station::PollingStation, proposal::Proposal, voters::Set{Pseudonym}[, collector::Pseudonym])

Creates a new ballotbox for given proposal with provided member pseudonyms at a relative generator anchored in the proposal. 
A collector is optional and provided only when it differs from one specified in the proposal. 
"""
function add!(station::PollingStation, spec::DemeSpec, proposal::Proposal, voters::Vector{Pseudonym}, collector::Pseudonym)
    bbox = BallotBox(proposal, voters, spec, collector)
    push!(station.halls, bbox)
    return
end

add!(station::PollingStation, spec::DemeSpec, proposal::Proposal, voters::Vector{Pseudonym}) = add!(station, spec, proposal, voters, proposal.collector)

"""
    ballotbox(station::PollingStation, uuid::UUID)::BallotBox

Return a ballotbox ledger with a provided UUID. If none is found throws an error.
"""
function ballotbox(station::PollingStation, _uuid::UUID) 

    for hall in station.halls
        if uuid(hall) == _uuid
            return hall
        end
    end

    error("BallotBox with uuid = $(_uuid) not found")
    return
end

"""
    record!(station::PollingStation, uuid::UUID, vote::Vote)::Int

Records a `vote` in a ballotbox with provided proposal UUID. Throws an error
if a ballotbox can't be found.
"""
function record!(station::PollingStation, uuid::UUID, vote::Vote)
    
    bbox = ballotbox(station, uuid)

    return record!(bbox, vote)
end

"""
    ballotbox(station::PollingStation, proposal::Digest)::BallotBox

Return a ballotbox which has proposal with provided digest.
"""
function ballotbox(station::PollingStation, proposal::Digest)

    for hall in station.halls

        p = hall.proposal
        if diggest(p, p.crypto) == proposal
            return hall
        end
    end

    error("BallotBox with proposal diggest $(proposal) not found")
end

"""
    record!(station::PollingStation, uuid::UUID, vote::Vote)::Int

Record a `vote` in a ballotbox found by proposal diggest stored in the vote. 
Throws an error if a ballotbox can't be found.
"""
function record!(station::PollingStation, vote::Vote)
    
    bbox = ballotbox(station, vote.proposal)

    return record!(bbox, vote, station.crypto)
end


"""
    commit!(station::PollingStation, uuid::UUID, collector::Signer; with_tally = nothing)

Select a ballotbox with provided uuid and commit it's state with collector. 
"""
commit!(station::PollingStation, uuid::UUID, signer::Signer; with_tally::Union{Bool, Nothing} = nothing) = commit!(ballotbox(station, uuid), signer; with_tally)

"""
    commit(station::PollingStation, uuid::UUID)::Commit

Return a ballotbox commit.
"""
commit(station::PollingStation, uuid::UUID) = commit(ballotbox(station, uuid))

"""
    ack_leaf(station::PollingStation, uuid::UUID, N::Int)::AckInclusion

Return history tree inclusion proof for a tree leaf at index `N` in ballotbox with `uuid`.
"""
ack_leaf(station::PollingStation, uuid::UUID, N::Int) = ack_leaf(ballotbox(station, uuid), N)

"""
    ack_root(station::PollingStation, uuid::UUID, N::Int)::AckConsistency

Return history tree consitency proof tree root at index `N` in ballotbox with `uuid`.
"""
ack_root(station::PollingStation, uuid::UUID, N::Int) = ack_root(ballotbox(station, uuid), N)

"""
    ack_cast(station::PollingStation, uuid::UUID, N::Int)::CastAck

Return inclusion proof with receipt and current tree commit for a leaf at index `N` and ballotbox with `uuid`. 
"""
ack_cast(station::PollingStation, uuid::UUID, N::Int) = ack_cast(ballotbox(station, uuid), N)

# """
#     record(station::PollingStation, uuid::UUID, N::Int)::CastRecord

# Return a record with an index `N` at ballotbox with `uuid`.
# """
# record(station::PollingStation, uuid::UUID, N::Int) = record(ballotbox(station, uuid), N)

Base.get(station::PollingStation, uuid::UUID) = ballotbox(station, uuid) # TODO: use select


"""
    spine(station::PollingStation, uuid::UUID)::Vector{Digest}

Return a leaf vector for a ballotbox with proposal `uuid`.
"""
spine(station::PollingStation, uuid::UUID) = spine(ballotbox(station, uuid))

"""
    receipt(station::PollingStation, uuid::UUID, N::Int)::CastReceipt

Return a receipt for a record with index `N` at ballotbox with `uuid`.
"""
receipt(station::PollingStation, uuid::UUID, N::Int) = receipt(ballotbox(station, uuid), N)

"""
    ledger(station::PollingStation, uuid::UUID)::Vector{CastRecord}

Return a vector of records from a ballotbox with `uuid`.
"""
ledger(station::PollingStation, uuid::UUID) = ledger(ballotbox(station, uuid))

"""
    tally(station::PollingStation, uuid::UUID)

Compute a tally from ledger records a ballotbox with `uuid`.
"""
tally(station::PollingStation, uuid::UUID) = tally(ballotbox(station, uuid))

"""
    set_seed!(station::PollingStation, uuid::UUID, seed::Digest)

Sets a seed for a ballotbox with provided `uuid`.
"""
set_seed!(station::PollingStation, uuid::UUID, seed::Digest) = set_seed!(ballotbox(station, uuid), seed)



#end
