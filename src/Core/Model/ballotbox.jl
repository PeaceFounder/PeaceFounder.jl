using Base: UUID
using Dates: DateTime


"""
    struct Ballot
        options::Vector{String}
    end

Represents a simple ballot form for multiple choice question. 
"""
struct Ballot
    options::Vector{String}
end

@batteries Ballot
"""
    struct Selection
        option::Int
    end

Represents voter's selection for a `Ballot` form.
"""
struct Selection
    option::Int
end

@batteries Selection
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

@batteries Tally

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

@batteries Proposal

function Base.in(proposal::Proposal, chain::BraidChainLedger)
    
    braid_index = proposal.anchor.index
    N = findfirst(==(proposal), view(chain, braid_index:length(chain)))

    return !isnothing(N)
end


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



isdone(proposal::Proposal; time) = proposal.closed < time
isopen(proposal::Proposal; time) = proposal.open < time && proposal.closed > time
isstarted(proposal::Proposal; time) = proposal.open < time

"""
    issuer(proposal::Proposal)

Issuer of approval for the proposal.
"""
issuer(proposal::Proposal) = isnothing(proposal.approval) ? nothing : pseudonym(proposal.approval)
index(proposal::Proposal) = index(proposal.anchor)


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
    seal::Union{Seal, Nothing} # It is unclear whether public key needs to be part of a signature
end

Vote(proposal::Digest, seed::Digest, selection::Selection, seq::Int) = Vote(proposal, seed, selection, seq, nothing)

Base.:(==)(x::Vote, y::Vote) = x.proposal == y.proposal && x.selection == y.selection && x.seq == y.seq && x.seal == y.seal

seed(vote::Vote) = vote.seed

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
function vote(proposal::Proposal, seed::Digest, selection::Selection, signer::Signer; seq = 1, force = false)

    force || @assert isconsistent(selection, proposal.ballot)
    
    proposal_digest = digest(proposal, hasher(signer.spec))

    #_seq = seq(signer, proposal_digest) + 1

    vote = Vote(proposal_digest, seed, selection, seq)

    approval = seal(vote, generator(proposal), signer::Signer; timestamp = proposal.open)
    
    return @set vote.seal = approval
end

"""
    isbinding(vote::Vote, proposal::Proposal, crypto::HashSpec)

Check that the vote is bound to a proposal.. 
"""
isbinding(vote::Vote, proposal::Proposal, spec::HashSpec) = vote.proposal == digest(proposal, spec)

isbinding(record, spine::Vector{Digest}, spec::HashSpec) = isbinding(record, spine, spec)

"""
    pseudonym(vote::Vote)::Union{Pseudonym, Nothing}

Return a pseudonym with which vote is sealed.
"""
pseudonym(vote::Vote) = isnothing(vote.seal) ? nothing : pseudonym(vote.seal) 

issuer(vote::Vote) = isnothing(vote.seal) ? nothing : issuer(vote.seal)


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
struct BallotBoxState
    proposal::Digest
    seed::Digest
    index::Int
    root::Digest
    tally::Union{Nothing, Tally} 
    view::Union{Nothing, BitVector} # 
end 

@batteries BallotBoxState

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

isbinding(state::BallotBoxState, proposal::Proposal, hasher::HashSpec) = state.proposal == digest(proposal, hasher)

isbinding(commit::Commit{BallotBoxState}, proposal::Proposal, hasher::HashSpec) = issuer(commit) == proposal.collector && isbinding(state(commit), proposal, hasher)


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

Base.:(==)(x::CastRecord, y::CastRecord) = x.vote == y.vote && x.timestamp == y.timestamp

seed(record::CastRecord) = seed(record.vote)

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
    receipt(record::CastRecord, hasher::HashSpec)::CastReceipt

Construct a CastReceipt from a CastRecord with a provided hasher function.
"""
receipt(record::CastRecord, hasher::HashSpec) = CastReceipt(digest(record.vote, hasher), record.timestamp)
receipt(record::CastRecord, spec) = receipt(record, hasher(spec))


isbinding(receipt::CastReceipt, spine::Vector{Digest}, hasher::HashSpec) = digest(receipt, hasher) in spine
isbinding(record::CastRecord, spine::Vector{Digest}, hasher::HashSpec) = isbinding(receipt(record, hasher), spine, hasher)

issuer(record::CastRecord) = issuer(record.vote)

"""
    isbinding(receipt::CastReceipt, vote::Vote, hasher::HashSpec)::Bool

Check that the receipt is bidning to a vote. 
"""
isbinding(receipt::CastReceipt, vote::Vote, hasher::HashSpec) = receipt.vote == digest(vote, hasher)


struct BallotBoxLedger
    records::AbstractVector{CastRecord}
    proposal::Proposal # could be a dublicate
    # seed::Digest # The seed is more like operational, and one only needs to compare that it is equal to all votes
    spec::DemeSpec # needs to be most recent one. In case the collector is different it can be passed as parameters
end

#Base.push!(ledger::BraidChainLedger, vote::Vote) = push!(ledger.records, record)

Base.push!(ledger::BallotBoxLedger, record::CastRecord) = push!(ledger.records, record)
Base.getindex(ledger::BallotBoxLedger, index::Int) = ledger.records[index]
Base.length(ledger::BallotBoxLedger) = length(ledger.records)
Base.findfirst(f::Function, ledger::BallotBoxLedger) = findfirst(f, ledger.records) 

Base.iterate(ledger::BallotBoxLedger) = iterate(ledger.records)
Base.iterate(ledger::BallotBoxLedger, index) = iterate(ledger.records, index)

Base.view(ledger::BallotBoxLedger, args) = BallotBoxLedger(view(ledger.records, args), ledger.proposal, ledger.spec)

generator(ledger::BallotBoxLedger) = generator(ledger.proposal)
uuid(ledger::BallotBoxLedger) = uuid(ledger.proposal)


function root(ledger::BallotBoxLedger, N::Int)

    (; spec) = ledger
    
    leafs = Digest[]

    for record in view(ledger, 1:N)
        push!(leafs, digest(record, hasher(spec)))
    end

    tree = HistoryTree(leafs, hasher(spec)) # this executes tree hash directly
    return HistoryTrees.root(tree)
end


function selections(bbox::BallotBoxLedger, N::Int = length(bbox))

    bitmask = tally_bitmask(bbox, N)
    
    return (i.vote.selection for i in view(view(bbox.records, 1:N), bitmask)) # perhaps view also suppoerts bitmask
end

function tally_bitmask(votes::AbstractVector{CastRecord}, ballot::Ballot) # tally_bitmask or counting_bitmask, counted_votes
    
    function lt(x::CastRecord, y::CastRecord)

        if x.vote.seal.pbkey != y.vote.seal.pbkey
            return x.vote.seal.pbkey < y.vote.seal.pbkey
        elseif x.vote.seq != y.vote.seq
            return x.vote.seq < y.vote.seq
        else
            # first recorded vote is counted if one already with the same sequence number exists
            # this prevents a silent attack where adversary who has gained access to crednetials
            # could cast a vote in place of absent voter.
            x.timestamp > y.timestamp 
        end
    end

    valid_votes = BitVector(false for i in 1:length(votes))    

    sorted_votes = collect(enumerate(votes))
    sort!(sorted_votes; lt = (x, y) -> lt(x[2], y[2]), rev=true)

    pbkeyi = nothing

    for (i, record) in sorted_votes
     
        if pbkeyi == record.vote.seal.pbkey
            continue
        end
   
        if isconsistent(record.vote.selection, ballot)
            valid_votes[i] = true
            pbkeyi = record.vote.seal.pbkey 
        end

    end

    return valid_votes
end

tally_bitmask(bbox::BallotBoxLedger, N::Int = length(bbox)) = tally_bitmask(view(bbox.records, 1:N), bbox.proposal.ballot)


"""
    tally(ledger::BallotBox)

Compute a tally for a ballotbox ledger. 
"""
tally(ledger::BallotBoxLedger, N::Int = length(ledger)) = tally(ledger.proposal.ballot, selections(ledger, N))


"""
    state(ledger::BallotBoxLedger; seed::Digest, root::Digest = root(ledger), with_tally::Union{Nothing, Bool} = nothing)::BallotBoxState

Return a state metadata for ballotbox ledger. 
"""
function state(ledger::BallotBoxLedger, N = length(ledger); seed::Digest, root::Union{Digest, Nothing} = root(ledger, N), with_tally::Bool = false)
    
    if with_tally
        _tally = tally(ledger, N)
        _view = tally_bitmask(ledger, N)
    else
        _tally = nothing
        _view = nothing
    end

    proposal = digest(ledger.proposal, ledger.spec)

    return BallotBoxState(proposal, seed, length(ledger), root, _tally, _view)
end


# N = length(ledger)
# TODO: Implement state for arbitrary index
# function state(ledger::BallotBoxLedger, N::Int; seed::Digest, root::Digest, with_tally::Union{Nothing, Bool} = nothing) end
