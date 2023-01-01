using Base: UUID

struct Ballot
    options::Vector{String}
end

struct Selection
    option::Int
end

isconsistent(selection::Selection, ballot::Ballot) = 1 <= selection.option <= length(ballot.options)

struct Tally
    data::Vector{Int}
end

# This one could be used for parametrization
selection_type(::Type{Ballot}) = Selection
tally_type(::Type{Ballot}) = Tally


function tally(ballot::Ballot, selections::AbstractVector{Selection})
    
    _tally = zeros(Int, length(ballot.options))

    for s in selections

        if isconsistent(s, ballot)

            _tally[s.option] += 1

        else
            @warn "Invalid selection, continuiing without"
        end
    end

    return Tally(_tally)
end


tally(ballot::Ballot, selections::Base.Generator) = tally(ballot, collect(selections))



struct Proposal <: Transaction 
    uuid::UUID
    summary::String
    description::String
    ballot::Ballot
    open::DateTime
    closed::DateTime
    collector::Pseudonym # 
    
    state::ChainState
    approval::Union{Seal, Nothing} 

    Proposal(uuid::UUID, summary::String, description::String, ballot::Ballot, open::DateTime, closed::DateTime, collector::Pseudonym, state::ChainState, approval::Union{Seal, Nothing}) = new(uuid, summary, description, ballot, open, closed, collector, state, approval)


    Proposal(; uuid, summary, description, ballot, open, closed, collector, state, approval = nothing) = Proposal(uuid, summary, description, ballot, open, closed, collector, state, approval)
end

state(proposal::Proposal) = proposal.state
generator(proposal::Proposal) = generator(state(proposal))

uuid(proposal::Proposal) = proposal.uuid

# isconsistent 
isbinding(chain::BraidChain, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)

isdone(proposal::Proposal; time) = proposal.closed < time
isopen(proposal::Proposal; time) = proposal.open < time && proposal.closed > time
isstarted(proposal::Proposal; time) = proposal.open < time


function Base.:(==)(x::Proposal, y::Proposal)

    x.summary == y.summary || return false
    x.description == y.description || return false
    x.options == y.options || return false
    x.open == y.open || return false
    x.closed == y.closed || return false
    x.mset == y.mset || return false
    x.generator == y.generator || return false
    x.treehash == y.treehash || return false
    x.approval == y.approval || return false

    return true
end



function Base.push!(chain::BraidChain, p::Proposal)
    push!(chain.ledger, p)
    push!(chain.tree, digest(p, hasher(chain.crypto)))
    return
end


function record!(chain::BraidChain, p::Proposal)

    # avoiding dublicates
    for (N, i) in enumerate(ledger(chain))
        if i isa Proposal && uuid(i) == uuid(p)
            if body(i) == body(p)
                return N
            else
                error("Can't register proposal as a different proposal with given uuid already exists in the chain.")
            end
        end
    end

    @assert isbinding(chain, state(p))
    @assert pseudonym(p.approval) == chain.guardian
    @assert verify(p, chain.crypto)
    
    push!(chain, p)

    N = length(chain)

    return N
end

# It could also throw an error 
members(chain::BraidChain, proposal::Proposal) = members(chain, proposal.state)

select(::Type{Proposal}, uuid::UUID, chain::BraidChain) = select(Proposal, x -> x.uuid == uuid, chain)


struct Vote
    proposal::Digest
    seed::Digest
    selection::Selection
    seq::Int
    approval::Union{Seal, Nothing} # It is unclear whether public key needs to be part of a signature
end

Vote(proposal::Digest, seed::Digest, selection::Selection, seq::Int) = Vote(proposal, seed, selection, seq, nothing)


Base.:(==)(x::Vote, y::Vote) = x.proposal == y.proposal && x.selection == y.selection && x.seq == y.seq && x.approval == y.approval

# I could have Vote{<:Option}, Proposal{<:AbstractBallot} and AbstractTally to accomodate different voting scenarious.
# The selection is associated here with Ballot parametric type
function vote(proposal::Proposal, seed::Digest, selection::Selection, signer::Signer)

    @assert isconsistent(selection, proposal.ballot)
    
    proposal_digest = digest(proposal, hasher(signer.spec))

    _seq = seq(signer, proposal_digest) + 1

    vote = Vote(proposal_digest, seed, selection, _seq)

    approval = seal(vote, generator(proposal), signer::Signer)
    
    return @set vote.approval = approval
end

isbinding(vote::Vote, proposal::Proposal, crypto::Crypto) = vote.proposal == digest(proposal, hasher(crypto))

isbinding(vote::Vote, spine::Vector{Digest}, crypto::Crypto) = digest(vote, hasher(crypto)) in spine

pseudonym(vote::Vote) = pseudonym(vote.approval)



struct BallotBoxState
    seed::Digest
    index::Int
    root::Digest
    tally::Union{Nothing, Tally} 
end

BallotBoxState(seed::Digest, index::Int, root::Nothing, tally::Nothing) = BallotBoxState(seed, index, Digest(), tally)

index(state::BallotBoxState) = state.index
root(state::BallotBoxState) = state.root

seed(state::BallotBoxState) = state.seed
seed(commit::Commit{BallotBoxState}) = seed(state(commit))

tally(state::BallotBoxState) = state.tally
tally(commit::Commit{BallotBoxState}) = tally(state(commit))

istallied(state::BallotBoxState) = !isnothing(state.tally)
istallied(commit::Commit{BallotBoxState}) = istallied(state(commit))


mutable struct BallotBox
    proposal::Proposal
    voters::Set{Pseudonym} # better than members
    collector::Pseudonym
    seed::Union{Digest, Nothing}
    crypto::Crypto # on the other hand the inclusion of a vote should be binding enough as it includes proposal hash.
    ledger::Vector{Vote}
    tree::HistoryTree
    commit::Union{Commit{BallotBoxState}, Nothing}
end


BallotBox(proposal::Proposal, voters::Set{Pseudonym}, collector::Pseudonym, crypto::Crypto) = BallotBox(proposal, voters, collector, nothing, crypto, Vote[], HistoryTree(Digest, hasher(crypto)), nothing)


generator(ballotbox::BallotBox) = generator(ballotbox.proposal)
uuid(ballotbox::BallotBox) = uuid(ballotbox.proposal)
members(ballotbox) = ballotbox.voters


ledger(ballotbox::BallotBox) = ballotbox.ledger
spine(ballotbox::BallotBox) = ballotbox.tree.d # 

Base.length(ballotbox::BallotBox) = length(ledger(ballotbox))

index(ballotbox::BallotBox) = length(ballotbox)

seed(ballotbox::BallotBox) = ballotbox.seed

leaf(ballotbox::BallotBox, N::Int) = leaf(ballotbox.tree, N)
root(ballotbox::BallotBox, N::Int) = root(ballotbox.tree, N)
root(ballotbox::BallotBox) = root(ballotbox.tree)

record(ballotbox::BallotBox, N::Int) = ledger(ballotbox)[N]

commit(ballotbox::BallotBox) = !isnothing(ballotbox.commit) ? ballotbox.commit : error("commitment not defined")


selections(votes::Vector{Vote}) = (i.selection for i in votes) # Note that dublicates are removed at this stage

tally(ballotbox::BallotBox) = tally(ballotbox.proposal.ballot, selections(ledger(ballotbox)))

istallied(ballotbox::BallotBox) = istallied(ballotbox.commit)

set_seed!(ballotbox::BallotBox, seed::Digest) = ballotbox.seed = seed;



function ack_leaf(ballotbox::BallotBox, index::Int) 

    @assert commit_index(ballotbox) >= index

    proof = InclusionProof(ballotbox.tree, index)

    return AckInclusion(proof, commit(ballotbox))
end

isbinding(vote::Vote, ack::AckInclusion{BallotBoxState}, crypto::Crypto) = digest(vote, crypto) == leaf(ack)


function ack_root(ballotbox::BallotBox, N::Int) 

    @assert commit_index(ballotbox) >= index

    proof = ConsistencyProof(ballotbox.tree, index)

    return AckConsistency(proof, commit(ballotbox))
end


commit_index(ballotbox::BallotBox) = index(commit(ballotbox))
commit_state(ballotbox::BallotBox) = state(commit(ballotbox))

function Base.push!(ballotbox::BallotBox, vote::Vote) 
    
    push!(ballotbox.tree, digest(vote, ballotbox.crypto))
    push!(ballotbox.ledger, vote)

    return
end


function state(ballotbox::BallotBox; with_tally::Union{Nothing, Bool} = nothing)

    # nothing follows the current state
    if isnothing(with_tally)
        if isnothing(ballotbox.commit) || isnothing(ballotbox.commit.state.tally)
            with_tally = false
        else
            with_tally = true
        end
    end

    if with_tally
        _tally = tally(ballotbox)
    else
        _tally = nothing
    end

    return BallotBoxState(seed(ballotbox), index(ballotbox), root(ballotbox), _tally)
end



function record!(ballotbox::BallotBox, vote::Vote, crypto::Crypto)

    N = findfirst(==(vote), ledger(ballotbox))
    !isnothing(N) && return N

    @assert isconsistent(vote.selection, ballotbox.proposal.ballot)
    @assert isbinding(vote, ballotbox.proposal, crypto) # isbinding(proposal(ballotbox), vote, crypto) 
    @assert pseudonym(vote) in members(ballotbox)

    @assert verify(vote, generator(ballotbox), crypto)

    push!(ballotbox, vote)
    N = length(ballotbox) # here it is important to have a proper length of the data!
    
    return N
end

function commit!(ballotbox::BallotBox, signer::Signer; with_tally::Union{Nothing, Bool} = nothing)

    _state = state(ballotbox; with_tally)
    ballotbox.commit = Commit(_state, seal(_state, signer))

    return
end



struct PollingStation
    halls::Vector{BallotBox}
    crypto::Crypto
end

PollingStation(crypto::Crypto) = PollingStation(BallotBox[], crypto)

function add!(station::PollingStation, proposal::Proposal, voters::Set{Pseudonym}, collector::Pseudonym)
    bbox = BallotBox(proposal, voters, collector, station.crypto)
    push!(station.halls, bbox)
    return
end

add!(station::PollingStation, proposal::Proposal, voters::Set{Pseudonym}) = add!(station, proposal, voters, proposal.collector)


function ballotbox(station::PollingStation, _uuid::UUID) 

    for hall in station.halls
        if uuid(hall) == _uuid
            return hall
        end
    end

    error("BallotBox with uuid = $(_uuid) not found")
    return
end


function record!(station::PollingStation, uuid::UUID, vote::Vote)
    
    bbox = ballotbox(station, uuid)

    return record!(bbox, vote, station.crypto)
end


function ballotbox(station::PollingStation, proposal::Digest)

    for hall in station.halls

        p = hall.proposal
        if diggest(p, p.crypto) == proposal
            return hall
        end
    end

    error("BallotBox with proposal diggest $(proposal) not found")
end


function record!(station::PollingStation, vote::Vote)
    
    bbox = ballotbox(station, vote.proposal)

    return record!(bbox, vote, station.crypto)
end


commit!(station::PollingStation, uuid::UUID, signer::Signer; with_tally::Union{Bool, Nothing} = nothing) = commit!(ballotbox(station, uuid), signer; with_tally)

commit(station::PollingStation, uuid::UUID) = commit(ballotbox(station, uuid))

ack_leaf(station::PollingStation, uuid::UUID, N::Int) = ack_leaf(ballotbox(station, uuid), N)
ack_root(station::PollingStation, uuid::UUID, N::Int) = ack_root(ballotbox(station, uuid), N)


record(station::PollingStation, uuid::UUID, N::Int) = record(ballotbox(station, uuid), N)
spine(station::PollingStation, uuid::UUID) = spine(ballotbox(station, uuid))

ledger(station::PollingStation, uuid::UUID) = ledger(ballotbox(station, uuid))

tally(station::PollingStation, uuid::UUID) = tally(ballotbox(station, uuid))


set_seed!(station::PollingStation, uuid::UUID, seed::Digest) = set_seed!(ballotbox(station, uuid), seed)
