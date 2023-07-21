using Base: UUID
using Dates: DateTime

"""
    struct Ballot
        options::Vector{String}
    end

Represents a simple ballot form for multiple choice question. 
"""
@struct_hash_equal struct Ballot
    options::Vector{String}
end

#@batteries Ballot
"""
    struct Selection
        option::Int
    end

Represents voter's selection for a `Ballot` form.
"""
@struct_hash_equal struct Selection
    option::Int
end

#@batteries Selection
"""
    isconsistent(selection::Selection, ballot::Ballot)

Verifies that voter's selection is consistent with ballot form. For instance, whether selection 
is withing the range of ballot options.
"""
isconsistent(selection::Selection, ballot::Ballot) = 1 <= selection.option <= length(ballot.options)

"""
    struct Tally
        data::Vector{Int}
    end

Represent a tally for `Ballot` form obtained aftert counting multiple voter's `Selection` forms.
"""
struct Tally
    data::Vector{Int}
end

# This one could be used for parametrization
selection_type(::Type{Ballot}) = Selection
tally_type(::Type{Ballot}) = Tally

"""
    tally(ballot::Ballot, ballots::AbstractVector{Selection})::Tally

Count ballots, check that they are filled consistently and return a final tally.
"""
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


"""
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
    end

Represents a proposal for a ballot specyfing voting window, unique identifier, summary, description. Set's the collector identity
which collects votes and issues vote inclusion receipts and is responsable for maintaining the ledger's integrity. The proposal
also includes an `anchor` which sets a relative generator with which members vote anonymously. To be considered valid is signed by
`proposer` authorizing vote to take place.
"""
@struct_hash_equal struct Proposal <: Transaction 
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

#@batteries Proposal
"""
    state(proposal::Proposal)::ChainState

A braidchain ledger state which is used to anchor a relative generator for members.
"""
state(proposal::Proposal) = proposal.anchor

"""
    generator(proposal::Proposal)

A relative generator for at which memebers sign votes for this proposal.
"""
generator(proposal::Proposal) = isnothing(proposal.anchor) ? nothing : generator(state(proposal))

"""
    uuid(proposal::Proposal)::UUID

UUID for a proposal. Issued by proposer and it's purpose is to croslink to an external system durring the proposal dreafting stage.
"""
uuid(proposal::Proposal) = proposal.uuid

"""
    isbinding(chain::BraidChain, state::ChainState)::Bool

Check that chain state is consistent with braidchain ledger.
"""
isbinding(chain::BraidChain, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)


isdone(proposal::Proposal; time) = proposal.closed < time
isopen(proposal::Proposal; time) = proposal.open < time && proposal.closed > time
isstarted(proposal::Proposal; time) = proposal.open < time

"""
    issuer(proposal::Proposal)

Issuer of approval for the proposal.
"""
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

function Base.push!(chain::BraidChain, p::Proposal)
    push!(chain.ledger, p)
    push!(chain.tree, digest(p, hasher(chain.spec)))
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
    @assert pseudonym(p.approval) == chain.spec.proposer
    @assert verify(p, crypto(chain.spec))
    
    push!(chain, p)

    N = length(chain)

    return N
end

# It could also throw an error 
members(chain::BraidChain, proposal::Proposal) = members(chain, proposal.anchor)

select(::Type{Proposal}, uuid::UUID, chain::BraidChain) = select(Proposal, x -> x.uuid == uuid, chain)

"""
    struct Vote
        proposal::Digest
        seed::Digest
        selection::Selection
        seq::Int
        approval::Union{Seal, Nothing} 
    end

Represents a vote for a proposal issued by a member. The `proposal` is stored as hash digest ensuring that member have voted on an untampered proposal. `seed` contains a randon string issued by collector at the moment when a vote starts to eliminate early voting / shortening a time at which coercers could act uppon. `selection` contians voter's preference; 

`seq` is a serquence number counting a number of votes at which vote have been approved for a given proposal. It starts at 1 and is increased by one for every single signature made on the proposal. This is an important measure which allows to detect possible leakage of a member's private key. Also provides means for revoting ensuring that latest vote get's counted.

The vote is considered valid when it is sealed by a member's private key at a relative generator stored in the proposal. 

"""
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

"""
    vote(proposal::Proposal, seed::Digest, selection::Selection, member::Signer; seq = 1)

Issue a vote on a proposal and provided collector `seed` for a member's `selection`. 
"""
function vote(proposal::Proposal, seed::Digest, selection::Selection, signer::Signer; seq = 1)

    @assert isconsistent(selection, proposal.ballot)
    
    proposal_digest = digest(proposal, hasher(signer.spec))

    #_seq = seq(signer, proposal_digest) + 1

    vote = Vote(proposal_digest, seed, selection, seq)

    approval = seal(vote, generator(proposal), signer::Signer)
    
    return @set vote.approval = approval
end

"""
    isbinding(vote::Vote, proposal::Proposal, crypto::CryptoSpec)

Check that the vote is bound to a proposal.. 
"""
isbinding(vote::Vote, proposal::Proposal, crypto::CryptoSpec) = vote.proposal == digest(proposal, hasher(crypto))

isbinding(record, spine::Vector{Digest}, crypto::CryptoSpec) = isbinding(record, spine, hasher(crypto))

"""
    pseudonym(vote::Vote)::Union{Pseudonym, Nothing}

Return a pseudonym with which vote is sealed.
"""
pseudonym(vote::Vote) = isnothing(vote.approval) ? nothing : pseudonym(vote.approval)

"""
    struct BallotBoxState
        proposal::Digest
        seed::Digest
        index::Int
        root::Digest
        tally::Union{Nothing, Tally} 
        view::Union{Nothing, BitVector} # 
    end 
        
Represents a public ballot box state. Contains an immutable proposal and seed digest; a current ledger `index`, history tree `root`. When ellections end a `tally` is included in the state and a `view` is added listing all counted votes. Note that the `view` attribute is important for a client to know whether it's key have leaked and somone lese havbe superseeded it's vote by revoting.
"""
@struct_hash_equal struct BallotBoxState
    proposal::Digest
    seed::Digest
    index::Int
    root::Digest
    tally::Union{Nothing, Tally} 
    view::Union{Nothing, BitVector} # 
end 

#@batteries BallotBoxState

BallotBoxState(proposal::Digest, seed::Digest, index::Int, root::Nothing, tally::Nothing, view::Nothing) = BallotBoxState(proposal, seed, index, Digest(), tally, view)

"""
    index(state::BallotBoxState)

Return an index for a current ballotbox ledger state.
"""
index(state::BallotBoxState) = state.index

"""
    root(state::BallotBoxState)

Return a history tree root for a current ballotbox ledger state.
"""
root(state::BallotBoxState) = state.root

seed(state::BallotBoxState) = state.seed
seed(commit::Commit{BallotBoxState}) = seed(state(commit))

tally(state::BallotBoxState) = state.tally
tally(commit::Commit{BallotBoxState}) = tally(state(commit))

istallied(state::BallotBoxState) = !isnothing(state.tally)
istallied(commit::Commit{BallotBoxState}) = istallied(state(commit))


isbinding(state::BallotBoxState, proposal::Proposal, hasher::Hash) = state.proposal == digest(proposal, hasher)

isbinding(commit::Commit{BallotBoxState}, proposal::Proposal, hasher::Hash) = issuer(commit) == proposal.collector && isbinding(state(commit), proposal, hasher)


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


function Base.show(io::IO, state::BallotBoxState)
    
    println(io, "BallotBoxState:")
    println(io, "  proposal : $(string(state.proposal))")
    println(io, "  seed : $(string(state.seed))")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    println(io, "  tally : $(tally(state))")

    view_str = isnothing(state.view) ? nothing : bitstring(state.view)
    print(io, "  view : $(view_str)")
end

"""
    struct CastRecord
        vote::Vote
        timestamp::DateTime
    end

Represents a ballotbox ledger record. Adds a timestamp when the vote have been recorded. In future,
the record will also contain a blind signature with which members could prove to everyone 
that they had cast their vote without revealing the link to the vote.
"""
struct CastRecord
    vote::Vote
    timestamp::DateTime
end

function Base.show(io::IO, receipt::CastRecord)

    println(io, "CastRecord:")
    println(io, show_string(receipt.vote))
    print(io, "  timestamp : $(receipt.timestamp)")

end

"""
    struct CastReceipt
        vote::Digest
        timestamp::DateTime
    end

Represents a ballotbox ledger receipt which is hashed for a history tree. It's sole purpose is
 to assure voters that their vote is included in the ledger while also adding additional metadata 
as timestamp and. In contrast to `CastRecord` it does not reveal 
how voter have voted thus can be published during ellections without violating fairness property. 
For some situations it may be useful to extend the time until the votes are published as that can 
disincentivice coercers and bribers as they would not know whether their coerced vote have been superseeded
in revoting. See [`receipt`](@ref) method for it's construction from a `CastRecord`.

Note that a blind signature could be commited as `H(signature|H(vote))` to avoid tagging the use of
pseudonym during ellections while collector could issue only a one blind signature for a voter. Note
that members whoose private key could have been stolen could not obtain a valid signature for participation
and that could be a good thing!
"""
struct CastReceipt
    vote::Digest
    timestamp::DateTime
end

function Base.show(io::IO, receipt::CastReceipt)

    println(io, "CastReceipt:")
    println(io, "  vote : $(string(receipt.vote))")
    print(io, "  timestamp : $(receipt.timestamp)")

end

"""
    receipt(record::CastRecord, hasher::Hash)::CastReceipt

Construct a CastReceipt from a CastRecord with a provided hasher function.
"""
receipt(record::CastRecord, hasher::Hash) = CastReceipt(digest(record.vote, hasher), record.timestamp)

"""
    isbinding(receipt::CastReceipt, ack::AckInclusion, hasher::Hash)::Bool

Check that cast receipt is binding to received inclusion acknowledgment.
"""
isbinding(receipt::CastReceipt, ack::AckInclusion, hasher::Hash) = digest(receipt, hasher) == leaf(ack)

isbinding(receipt::CastReceipt, spine::Vector{Digest}, hasher::Hash) = digest(receipt, hasher) in spine
isbinding(record::CastRecord, spine::Vector{Digest}, hasher::Hash) = isbinding(receipt(record, hasher), spine, hasher)


"""
    isbinding(receipt::CastReceipt, vote::Vote, hasher::Hash)::Bool

Check that the receipt is bidning to a vote. 
"""
isbinding(receipt::CastReceipt, vote::Vote, hasher::Hash) = receipt.vote == digest(vote, hasher)


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
    isbinding(ack::CastAck, proposal::Proposal, hasher::Hash)::Bool

Check that acknowledgment is legitimate meaning that it is issued by a collector listed in the proposal.
"""
isbinding(ack::CastAck, proposal::Proposal, hasher::Hash) = isbinding(ack.ack, proposal, hasher)

isbinding(ack::AckInclusion{BallotBoxState}, proposal::Proposal, hasher::Hash) = issuer(ack) == proposal.collector && state(ack).proposal == digest(proposal, hasher)

isbinding(ack::AckConsistency{BallotBoxState}, proposal::Proposal, hasher::Hash) = issuer(ack) == proposal.collector && state(ack).proposal == digest(proposal, hasher)

isbinding(ack::CastAck, vote::Vote, hasher::Hash) = isbinding(ack.receipt, vote, hasher)

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


BallotBox(proposal::Proposal, voters::Set{Pseudonym}, collector::Pseudonym, crypto::CryptoSpec) = BallotBox(proposal, voters, collector, nothing, crypto, Vote[], CastRecord[], HistoryTree(Digest, hasher(crypto)), nothing)


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

"""
    reset_tree!(ledger::BallotBox)

Recompute history tree root and cache from the elements in the ledger. This is a useful
for loading the ledger all at once.  
"""
function reset_tree!(ballotbox::BallotBox)

    d = Digest[digest(i, hasher(ballotbox.crypto)) for i in ballotbox.ledger]
    tree = HistoryTree(d, hasher(ballotbox.crypto))

    ballotbox.tree = tree

    return
end

"""
    generator(ledger::BallotBox)

Return a relative generator which members use to sign votes anchored by the proposal.
"""
generator(ballotbox::BallotBox) = generator(ballotbox.proposal)

"""
    uuid(ledger::BallotBox)

Return a UUID of the proposal.
"""
uuid(ballotbox::BallotBox) = uuid(ballotbox.proposal)

"""
    members(ledger::BallotBox)

Return a list of member pseudonyms with which members authetificate their votes.
"""
members(ballotbox) = ballotbox.voters

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

"""
    length(ledger::BallotBox)

Return a total length of the ledger including uncommited records in the queue.
"""
Base.length(ballotbox::BallotBox) = length(ledger(ballotbox)) + length(ballotbox.queue)

"""
    index(ledger::BallotBox)

Return the current index of the ledger. See also [`length`](@ref).
"""
index(ballotbox::BallotBox) = length(ledger(ballotbox))

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
receipt(ballotbox::BallotBox, N::Int) = receipt(record(ballotbox, N), hasher(ballotbox.crypto))

"""
    commit(ledger::BallotBox)

Return a commit for the ballotbox ledger.
"""
commit(ballotbox::BallotBox) = !isnothing(ballotbox.commit) ? ballotbox.commit : error("ballotbox had not been commited yet")


selections(votes::Vector{CastRecord}) = (i.vote.selection for i in votes) # Note that dublicates are removed at this stage
tallyview(votes::Vector{CastRecord}) = BitVector(true for i in votes) 

"""
    tally(ledger::BallotBox)

Compute a tally for a ballotbox ledger. 
"""
tally(ballotbox::BallotBox) = tally(ballotbox.proposal.ballot, selections(ledger(ballotbox)))
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
    
    push!(ballotbox.tree, digest(record, ballotbox.crypto))
    push!(ballotbox.ledger, record)

    return
end


"""
    state(ledger::BallotBox; with_tally::Union{Nothing, Bool} = nothing)::BallotBoxState

Return a state metadata for ballotbox ledger. 
"""
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

    proposal = digest(ballotbox.proposal, ballotbox.crypto)

    return BallotBoxState(proposal, seed(ballotbox), index(ballotbox), root(ballotbox), _tally, _view)
end


function get_dublicate_index(ballotbox::BallotBox, vote::Vote)

    N = findfirst(==(vote), (i.vote for i in ledger(ballotbox)))
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

    @assert isconsistent(vote.selection, ballotbox.proposal.ballot)
    @assert isbinding(vote, ballotbox.proposal, ballotbox.crypto) # isbinding(proposal(ballotbox), vote, crypto) 
    @assert pseudonym(vote) in members(ballotbox)

    @assert verify(vote, generator(ballotbox), ballotbox.crypto)

    return
end

"""
    record!(ledger::BallotBox, vote::Vote)

Check the vote for validity and pushes it to the queue. Returns an index `N`
at which the vote will be recorded in the ledger. See also [`push`](@ref)
"""
function record!(ballotbox::BallotBox, vote::Vote)

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

    @assert length(ballotbox.queue) == 0 "BallotBox have uncommited votes."

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
    crypto::CryptoSpec
end

PollingStation(crypto::CryptoSpec) = PollingStation(BallotBox[], crypto)


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
function add!(station::PollingStation, proposal::Proposal, voters::Set{Pseudonym}, collector::Pseudonym)
    bbox = BallotBox(proposal, voters, collector, station.crypto)
    push!(station.halls, bbox)
    return
end

add!(station::PollingStation, proposal::Proposal, voters::Set{Pseudonym}) = add!(station, proposal, voters, proposal.collector)

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

"""
    record(station::PollingStation, uuid::UUID, N::Int)::CastRecord

Return a record with an index `N` at ballotbox with `uuid`.
"""
record(station::PollingStation, uuid::UUID, N::Int) = record(ballotbox(station, uuid), N)

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
