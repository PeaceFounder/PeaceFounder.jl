using Base: UUID
using Dates: DateTime


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
    collector::Union{Pseudonym, Nothing} # 
    
    anchor::Union{ChainState, Nothing}
    approval::Union{Seal, Nothing} 

    Proposal(uuid::UUID, summary::String, description::String, ballot::Ballot, open::DateTime, closed::DateTime, collector::Union{Pseudonym, Nothing}, state::Union{ChainState, Nothing}, approval::Union{Seal, Nothing}) = new(uuid, summary, description, ballot, open, closed, collector, state, approval)


    Proposal(; uuid, summary, description, ballot, open, closed, collector = nothing, state = nothing, approval = nothing) = Proposal(uuid, summary, description, ballot, open, closed, collector, state, approval)
end

state(proposal::Proposal) = proposal.anchor
generator(proposal::Proposal) = isnothing(proposal.anchor) ? nothing : generator(state(proposal))

uuid(proposal::Proposal) = proposal.uuid

# isconsistent 
isbinding(chain::BraidChain, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)

isdone(proposal::Proposal; time) = proposal.closed < time
isopen(proposal::Proposal; time) = proposal.open < time && proposal.closed > time
isstarted(proposal::Proposal; time) = proposal.open < time


issuer(proposal::Proposal) = isnothing(proposal.approval) ? nothing : pseudonym(proposal.approval)

function status(proposal::Proposal)
    
    time = Dates.now()
    (; open, closed) = proposal

    if time < open
        return "pending"
    elseif time < closed
        return "started"
    else
        return "closed"
    end
end



function Base.show(io::IO, proposal::Proposal)
    
    println(io, "Proposal:")
    println(io, "  summary : $(proposal.summary)")
    println(io, "  uuid : $(proposal.uuid)")
    println(io, "  window : $(proposal.open) - $(proposal.closed) ($(status(proposal)))")
    println(io, "  generator : $(string(generator(proposal)))")
    println(io, "  collector : $(string(proposal.collector))")
    print(io, "  issuer : $(string(issuer(proposal)))")

end


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
members(chain::BraidChain, proposal::Proposal) = members(chain, proposal.anchor)

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


function Base.show(io::IO, vote::Vote)

    println(io, "Vote:")
    println(io, "  proposal : $(string(vote.proposal))")
    println(io, "  seed : $(string(vote.seed))")
    println(io, "  selection : $(vote.selection)")
    println(io, "  seq : $(vote.seq)")
    print(io, "  pseudonym : $(string(pseudonym(vote)))")

end

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


isbinding(record, spine::Vector{Digest}, crypto::Crypto) = isbinding(record, spine, hasher(crypto))

pseudonym(vote::Vote) = isnothing(vote.approval) ? nothing : pseudonym(vote.approval)


struct BallotBoxState
    seed::Digest
    index::Int
    root::Digest
    tally::Union{Nothing, Tally} 
    view::Union{Nothing, BitVector} # 
end 

@batteries BallotBoxState

BallotBoxState(seed::Digest, index::Int, root::Nothing, tally::Nothing, view::Nothing) = BallotBoxState(seed, index, Digest(), tally, view)

index(state::BallotBoxState) = state.index
root(state::BallotBoxState) = state.root

seed(state::BallotBoxState) = state.seed
seed(commit::Commit{BallotBoxState}) = seed(state(commit))

tally(state::BallotBoxState) = state.tally
tally(commit::Commit{BallotBoxState}) = tally(state(commit))

istallied(state::BallotBoxState) = !isnothing(state.tally)
istallied(commit::Commit{BallotBoxState}) = istallied(state(commit))


function Base.show(io::IO, state::BallotBoxState)
    
    println(io, "BallotBoxState:")
    println(io, "  seed : $(string(state.seed))")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    println(io, "  tally : $(tally(state))")

    view_str = isnothing(state.view) ? nothing : bitstring(state.view)
    print(io, "  view : $(view_str)")
end


struct CastRecord
    vote::Vote
    timestamp::DateTime
end

function Base.show(io::IO, receipt::CastRecord)

    println(io, "CastRecord:")
    println(io, show_string(receipt.vote))
    print(io, "  timestamp : $(receipt.timestamp)")

end

struct CastReceipt
    vote::Digest
    timestamp::DateTime
end

function Base.show(io::IO, receipt::CastReceipt)

    println(io, "CastReceipt:")
    println(io, "  vote : $(string(receipt.vote))")
    print(io, "  timestamp : $(receipt.timestamp)")

end

receipt(record::CastRecord, hasher::Hash) = CastReceipt(digest(record.vote, hasher), record.timestamp)

isbinding(receipt::CastReceipt, ack::AckInclusion, hasher::Hash) = digest(receipt, hasher) == leaf(ack)

isbinding(receipt::CastReceipt, spine::Vector{Digest}, hasher::Hash) = digest(receipt, hasher) in spine
isbinding(record::CastRecord, spine::Vector{Digest}, hasher::Hash) = isbinding(receipt(record, hasher), spine, hasher)

# A good place to also reply with a blind signature here for a proof of pariticpation
struct CastAck
    receipt::CastReceipt
    ack::AckInclusion
end

id(ack::CastAck) = id(ack.ack)

function verify(ack::CastAck, crypto::Crypto)
    isbinding(ack.receipt, ack.ack, hasher(crypto)) || return false
    return verify(ack.ack, crypto)
end

function Base.show(io::IO, ack::CastAck)

    println(io, "CastAck:")
    println(io, show_string(ack.receipt))
    println(io, show_string(ack.ack))

end


mutable struct BallotBox
    proposal::Proposal
    voters::Set{Pseudonym} # better than members
    collector::Pseudonym
    seed::Union{Digest, Nothing}
    crypto::Crypto # on the other hand the inclusion of a vote should be binding enough as it includes proposal hash.
    queue::Vector{Vote}
    ledger::Vector{CastRecord}
    tree::HistoryTree
    commit::Union{Commit{BallotBoxState}, Nothing}
end


BallotBox(proposal::Proposal, voters::Set{Pseudonym}, collector::Pseudonym, crypto::Crypto) = BallotBox(proposal, voters, collector, nothing, crypto, Vote[], CastRecord[], HistoryTree(Digest, hasher(crypto)), nothing)


function Base.show(io::IO, ballotbox::BallotBox)

    println(io, "BallotBox:")
    println(io, "  voters : $(length(ballotbox.voters)) entries")
    println(io, "  seed : $(string(ballotbox.seed))")
    println(io, "  queue : $(length(ballotbox.queue)) uncommited entries")
    println(io, show_string(ballotbox.proposal))
    println(io, "")

    print_vector(io, ballotbox.ledger)
    
    println(io, "")
    println(io, show_string(ballotbox.commit))

end


generator(ballotbox::BallotBox) = generator(ballotbox.proposal)
uuid(ballotbox::BallotBox) = uuid(ballotbox.proposal)
members(ballotbox) = ballotbox.voters


ledger(ballotbox::BallotBox) = ballotbox.ledger
spine(ballotbox::BallotBox) = ballotbox.tree.d # 

Base.length(ballotbox::BallotBox) = length(ledger(ballotbox)) + length(ballotbox.queue)

index(ballotbox::BallotBox) = length(ledger(ballotbox))

seed(ballotbox::BallotBox) = ballotbox.seed

leaf(ballotbox::BallotBox, N::Int) = leaf(ballotbox.tree, N)
root(ballotbox::BallotBox, N::Int) = root(ballotbox.tree, N)
root(ballotbox::BallotBox) = root(ballotbox.tree)

record(ballotbox::BallotBox, N::Int) = ledger(ballotbox)[N]
receipt(ballotbox::BallotBox, N::Int) = receipt(record(ballotbox, N), hasher(ballotbox.crypto))


commit(ballotbox::BallotBox) = !isnothing(ballotbox.commit) ? ballotbox.commit : error("commitment not defined")


selections(votes::Vector{CastRecord}) = (i.vote.selection for i in votes) # Note that dublicates are removed at this stage
tallyview(votes::Vector{CastRecord}) = BitVector(true for i in votes) 


tally(ballotbox::BallotBox) = tally(ballotbox.proposal.ballot, selections(ledger(ballotbox)))
tallyview(ballotbox::BallotBox) = tallyview(ballotbox.ledger)


istallied(ballotbox::BallotBox) = istallied(ballotbox.commit)

set_seed!(ballotbox::BallotBox, seed::Digest) = ballotbox.seed = seed;


function ack_leaf(ballotbox::BallotBox, index::Int) 

    @assert commit_index(ballotbox) >= index

    proof = InclusionProof(ballotbox.tree, index)

    return AckInclusion(proof, commit(ballotbox))
end

#isbinding(vote::Vote, ack::AckInclusion{BallotBoxState}, crypto::Crypto) = digest(vote, crypto) == leaf(ack)


isbinding(vote::Vote, ack::CastAck, crypto::Crypto) = digest(vote, crypto) == ack.receipt.vote

function ack_root(ballotbox::BallotBox, N::Int) 

    @assert commit_index(ballotbox) >= index

    proof = ConsistencyProof(ballotbox.tree, index)

    return AckConsistency(proof, commit(ballotbox))
end


function ack_cast(ballotbox::BallotBox, N::Int)
    
    ack = ack_leaf(ballotbox, N)
    _receipt = receipt(ballotbox, N)

    return CastAck(_receipt, ack)    
end



commit_index(ballotbox::BallotBox) = index(commit(ballotbox))
commit_state(ballotbox::BallotBox) = state(commit(ballotbox))

function Base.push!(ballotbox::BallotBox, record::CastRecord) 
    
    push!(ballotbox.tree, digest(record, ballotbox.crypto))
    push!(ballotbox.ledger, record)

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
        _view = tallyview(ballotbox)
    else
        _tally = nothing
        _view = nothing
    end

    return BallotBoxState(seed(ballotbox), index(ballotbox), root(ballotbox), _tally, _view)
end




function get_dublicate_index(ballotbox::BallotBox, vote::Vote)

    N = findfirst(==(vote), (i.vote for i in ledger(ballotbox)))
    !isnothing(N) && return N

    M = findfirst(==(vote), ballotbox.queue)
    !isnothing(M) && return M + length(ledger(ballotbox))
    
    return
end




function validate(ballotbox::BallotBox, vote::Vote)
    
    @assert isconsistent(vote.selection, ballotbox.proposal.ballot)
    @assert isbinding(vote, ballotbox.proposal, ballotbox.crypto) # isbinding(proposal(ballotbox), vote, crypto) 
    @assert pseudonym(vote) in members(ballotbox)

    @assert verify(vote, generator(ballotbox), ballotbox.crypto)

    return
end



function record!(ballotbox::BallotBox, vote::Vote)

    N = get_dublicate_index(ballotbox, vote)
    isnothing(N) || return N
    
    validate(ballotbox, vote)

    push!(ballotbox.queue, vote)

    N = length(ballotbox) # here it is important to have a proper length of the data!
    
    return N
end


function record!(ballotbox::BallotBox, record::CastRecord)

    @assert length(ballotbox.queue) == 0 "BallotBox have uncommited votes."

    (; vote ) = record

    N = get_dublicate_index(ballotbox, vote)
    isnothing(N) || return N

    validate(ballotbox, vote)

    push!(ballotbox, record)

    N = length(ballotbox) # here it is important to have a proper length of the data!
    
    return N
end



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



struct PollingStation
    halls::Vector{BallotBox}
    crypto::Crypto
end

PollingStation(crypto::Crypto) = PollingStation(BallotBox[], crypto)


function Base.show(io::IO, station::PollingStation)
    
    println(io, "PollingStation:")
    println(io, "")

    for i in station.halls
        println(io, show_string(i.proposal))
    end

end



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

    return record!(bbox, vote)
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
ack_cast(station::PollingStation, uuid::UUID, N::Int) = ack_cast(ballotbox(station, uuid), N)

record(station::PollingStation, uuid::UUID, N::Int) = record(ballotbox(station, uuid), N)
spine(station::PollingStation, uuid::UUID) = spine(ballotbox(station, uuid))

receipt(station::PollingStation, uuid::UUID, N::Int) = receipt(ballotbox(station, uuid), N)

ledger(station::PollingStation, uuid::UUID) = ledger(ballotbox(station, uuid))

tally(station::PollingStation, uuid::UUID) = tally(ballotbox(station, uuid))


set_seed!(station::PollingStation, uuid::UUID, seed::Digest) = set_seed!(ballotbox(station, uuid), seed)
