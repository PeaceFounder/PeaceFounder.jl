#module BraidChainController

# This module defines BraidChainController with the focus of exposing it to the Mapper layer and offering it's incremental state updates
# with the record! function. For the sake of simplicity all controllers may be combined under a single module Controllers.
# struct BraidBroker end # ToDo

using Base: UUID
using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof
using Dates: DateTime
using ..Core.Model: Pseudonym, Transaction, DemeSpec, Generator, Commit, ChainState, Signer, Membership, Termination, Proposal, BraidReceipt, Digest, hasher, digest, id, seal, pseudonym, crypto, verify, input_generator, input_members, output_generator, output_members, BraidChainLedger, issuer, show_string, ticket
using ..Core.ProtocolSchema: AckInclusion, AckConsistency

import ..Core.Model: isbinding, generator, members, voters, roll, blacklist, termination_bitmask

"""
    struct BraidChain
        members::Set{Pseudonym}
        ledger::BraidChainLedger
        spec::DemeSpec
        generator::Generator
        tree::HistoryTree
        commit::Union{Commit{ChainState}, Nothing}
    end

Represents a braidchain ledger with it's associated state. Can be instantitated with a demespec file using
`BraidChain(::DemeSpec)` method.

**Interface:**  [`push!`](@ref), [`record!`](@ref), [`state`](@ref), [`length`](@ref), [`list`](@ref), [`select`](@ref), [`generator`](@ref), [`commit`](@ref), [`commit_index`](@ref), [`ledger`](@ref), [`leaf`](@ref), [`root`](@ref), [`ack_leaf`](@ref), [`ack_root`](@ref), [`members`](@ref), [`commit!`](@ref)
"""
mutable struct BraidChainController
    members::Set{Pseudonym}
    ledger::BraidChainLedger
    spec::DemeSpec
    generator::Generator
    tickets::Set{TicketID} # new
    roll::Set{Pseudonym} # new (member count is evaluated from identities)
    blacklist::Set{Pseudonym} # new
    termination_bitmask::BitVector # new
    tree::HistoryTree
    commit::Union{Commit{ChainState}, Nothing}
end


function BraidChainController(spec::DemeSpec) 
    
    chain = BraidChainController(Set{Pseudonym}(), BraidChainLedger(Transaction[]), spec, generator(spec), Set{TicketID}(), Set{Pseudonym}(), Set{Pseudonym}(), BitVector(), HistoryTree(Digest, hasher(spec)), nothing)

    return chain
end


function BraidChainController(ledger::BraidChainLedger; commit = nothing)

    N = findlast(x -> x isa DemeSpec, ledger.records)
    spec = ledger[N]

    N = findlast(x -> x isa DemeSpec || x isa BraidReceipt, ledger.records)
    record = ledger[N]

    _generator = 
        record isa DemeSpec ? generator(record) :
        record isa BraidReceipt ? output_generator(record) : nothing

    tree = HistoryTree(Digest, hasher(spec))

    _members = members(ledger) 
    _identities = roll(ledger)
    _blacklist = blacklist(ledger)
    _termination_bitmask = termination_bitmask(ledger)
    tickets = Set{TicketID}(ticket(record) for record in ledger if record isa Membership)

    chain = BraidChainController(_members, ledger, spec, _generator, tickets, _identities, _blacklist, _termination_bitmask, tree, commit)
    
    reset_tree!(chain)

    return chain
end


function print_vector(io::IO, vector::Vector)
    
    for i in vector
        println(io, show_string(i))
    end
    
end


function Base.show(io::IO, chain::BraidChainController)

    println(io, "BraidChainController:")
    println(io, "  members : $(length(chain.members)) entries")
    println(io, "  generator : $(string(chain.generator))")
    println(io, "  guardian : $(string(issuer(chain.spec)))")
    println(io, "  recorder : $(string(chain.spec.recorder))")
    println(io, "")
    #println(io, show_string(chain.ledger))
    print_vector(io, chain.ledger.records)
    println(io, "")
    print(io, show_string(chain.commit))

end


function record!(chain::BraidChainController, spec::DemeSpec)

    @assert length(chain.ledger) == 0 "Reinitialization not yet implemented"

    push!(chain, spec)
    
    N = length(chain)

    return N
end


"""
    reset_tree!(ledger::BraidChainController)

Recompute a chain tree hash. 
"""
function reset_tree!(chain::BraidChainController)

    d = Digest[digest(i, hasher(chain.spec)) for i in chain.ledger]
    tree = HistoryTree(d, hasher(chain.spec))
    chain.tree = tree

    return
end

# Internal method. Shall never be used outside this file; used in four places justifying DRY
function unsafe_push!(chain::BraidChainController, record::Transaction)

    push!(chain.ledger, record)
    push!(chain.tree, digest(record, hasher(chain.spec)))
    push!(chain.termination_bitmask, false)

    return
end


"""
    push!(ledger::BraidChainController, t::Transaction)

Add an element to the BraidChainController bypassing transaction verification with the chain.
This should only be used when the ledger is loaded from a trusted source like
a local disk or when final root hash is validated with a trusted source.
"""
Base.push!(chain::BraidChainController, t::Transaction) = unsafe_push!(chain, t) # used by proposal

Base.length(chain::BraidChainController) = length(chain.ledger)

"""
    list(T, ledger::BraidChainController)::Vector{Tuple{Int, T}}

List braidchain elements with a given type together with their index.
"""
list(::Type{T}, chain::BraidChainController) where T <: Transaction = ((n,p) for (n,p) in enumerate(chain.ledger) if p isa T)

# list also accpets filter arguments. 
"""
    select(T, predicate::Function, ledger::BraidChainController)::Union{T, Nothing}

Return a first element from a ledger with a type `T` which satisfies a predicate. 
"""
function select(::Type{T}, f::Function, chain::BraidChainController) where T <: Transaction

    for i in chain.ledger
        if i isa T && f(i)
            return i
        end
    end

    return nothing
end


roll(chain::BraidChainController) = chain.roll

blacklist(chain::BraidChainController) = chain.blacklist

termination_bitmask(chain::BraidChainController) = copy(chain.termination_bitmask) 
termination_bitmask(chain::BraidChainController, N::Int) = termination_bitmask(chain.ledger, N)

"""
    generator(ledger::BraidChainController)

Return a current relative generator for a braidchain ledger.
"""
generator(chain::BraidChainController) = chain.generator

"""
    commit(ledger::BraidChainController)

Return a current commit for a braichain. 
"""
commit(chain::BraidChainController) = chain.commit

commit_index(chain::BraidChainController) = index(commit(chain))


ledger(chain::BraidChainController) = chain.ledger

"""
    leaf(ledger::BraidChainController, N::Int)::Digest

Return a ledger's element digest at given index.
"""
leaf(chain::BraidChainController, N::Int) = leaf(chain.tree, N)

"""
    root(ledger::BraidChainController[, N::Int])::Digest

Return a ledger root digest. In case when index is not given a current index is used.
"""
root(chain::BraidChainController) = root(chain.tree)
root(chain::BraidChainController, N::Int) = root(chain.tree, N)


Base.getindex(chain::BraidChainController, n::Int) = chain.ledger[n]

"""
    ack_leaf(ledger::BraidChainController, index::Int)::AckInclusion

Return a proof for record inclusion with respect to a current braidchain ledger history tree root. 
"""
function ack_leaf(chain::BraidChainController, index::Int) 

    @assert commit_index(chain) >= index
    
    proof = InclusionProof(chain.tree, index)
    
    return AckInclusion(proof, commit(chain))
end

"""
    ack_root(ledger::BraidChainController, index::Int)

Return a proof for the ledger root at given index with respect to the current braidchain ledger history tree root.
"""
function ack_root(chain::BraidChainController, index::Int) 
    
    @assert commit_index(chain) >= index
    
    proof = ConsistencyProof(chain.tree, index)
    
    return AckConsistency(proof, commit(chain))
end


"""
    generator(ledger[, index])

Return a generator at braidchain ledger row index. If `index` is omitted return the current state value.
"""
function generator(chain::BraidChainController, n::Int)
    
    for i in view(chain.ledger, n:-1:1) # I could also use a reverse there

        if i isa BraidReceipt
            return output_generator(i)
        end

    end

    return generator(chain.spec)
end


"""
    members(chain::BraidChainController, [n::Int])::Set

Return a set of member pseudonyms which at given anchor index can participate in voting or braiding.
"""
members(chain::BraidChainController, n::Int) = members(chain.ledger, n)
members(chain::BraidChainController, state::ChainState) = members(chain, state.index)
members(chain::BraidChainController) = chain.members

voters(chain::BraidChainController, anchor) = voters(ledger(chain), anchor)

"""
    state(ledger::BraidChainController)

Return a current braidchain ledger state metadata.
"""
#state(chain::BraidChainController) = ChainState(length(chain), root(chain), generator(chain), length(members(chain)))
state(chain::BraidChainController) = ChainState(length(chain), root(chain), generator(chain), length(roll(chain)), termination_bitmask(chain))
state(chain::BraidChainController, n::Int) = state(chain.ledger, n)


Base.findlast(::Type{T}, ledger::Vector{Transaction}) where T <: Transaction = findlast(x -> x isa T, ledger)
Base.findlast(::Type{T}, chain::BraidChainController) where T <: Transaction = findlast(T, chain.ledger)


"""
    commit!(ledger::BraidChainController, signer::Signer)

Commit a current braidchain ledger state with a signer's issued cryptographic signature. 
"""
function commit!(chain::BraidChainController, signer::Signer) 

    @assert chain.spec.recorder == id(signer)

    _state = state(chain)
    chain.commit = Commit(_state, seal(_state, signer))

    return
end


function Base.push!(chain::BraidChainController, m::Membership)

    push!(chain.members, pseudonym(m))
    #push!(chain.roll, issuer(m))
    push!(chain.tickets, ticket(m))
    push!(chain.roll, id(m))
    unsafe_push!(chain, m)

    return
end

function record!(chain::BraidChainController, m::Membership)

    N = findfirst(==(m), ledger(chain))
    !isnothing(N) && return N

    @assert generator(chain) == generator(m)
    @assert !(ticket(m) in chain.tickets) "Ticket already taken; Can't register a dublicate"
    @assert !(id(m) in roll(chain)) "Identity pseudonym is already registered"
    @assert !(id(m) in blacklist(chain)) "The pseudonym is blacklisted"
    @assert !(pseudonym(m) in members(chain))
    @assert issuer(m.admission) == chain.spec.registrar

    @assert verify(m, crypto(chain.spec)) # verifies also admission 

    push!(chain, m)

    return length(chain)
end

function Base.push!(chain::BraidChainController, braidwork::BraidReceipt)

    chain.generator = output_generator(braidwork)
    chain.members = Set(output_members(braidwork))
    unsafe_push!(chain, braidwork)

    return
end

function record!(chain::BraidChainController, braidwork::BraidReceipt)

    if braidwork.reset
        
        @assert input_generator(braidwork) == generator(chain.spec)
        @assert Set(input_members(braidwork)) == roll(chain)
        
        @assert issuer(braidwork) == chain.spec.braider
        @assert crypto(braidwork.producer) == crypto(chain.spec) 

    else

        @assert generator(chain) == input_generator(braidwork)
        @assert members(chain) == Set(input_members(braidwork))

    end

    @assert verify(braidwork, crypto(chain.spec)) "Braid is invalid"

    push!(chain, braidwork)

    return length(chain)
end


"""
    isbinding(chain::BraidChainController, state::ChainState)::Bool

Check that chain state is consistent with braidchain ledger.
"""
isbinding(chain::BraidChainController, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)


function record!(chain::BraidChainController, p::Proposal)

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
    @assert chain.ledger[state(p).index] isa BraidReceipt "Proposals can only be anchored on braids." 
    @assert verify(p, crypto(chain.spec))
    
    push!(chain, p)

    return length(chain)
end

select(::Type{Proposal}, uuid::UUID, chain::BraidChainController) = select(Proposal, x -> x.uuid == uuid, chain)


function Base.push!(chain::BraidChainController, termination::Termination)
    
    push!(chain.blacklist, termination.identity)

    if termination.index != 0
        chain.termination_bitmask[termination.index] = true
        pop!(chain.roll, termination.identity)

        member_cert = chain[termination.index]
        if generator(member_cert) == generator(chain)
            pop!(chain.members, pseudonym(member_cert)) # immediate termination
        end
    end

    unsafe_push!(chain, termination)

    return
end


function record!(chain::BraidChainController, termination::Termination)

    if termination.index == 0
        @assert !(id(termination) in chain.roll) "Termination index can't be zero; Membership with termination identity already recorded;"
    else
        @assert chain.termination_bitmask[termination.index] == false 
        @assert id(termination) in chain.roll "Identity not in ledger" 
        @assert id(chain.ledger[termination.index]) == id(termination)
    end

    @assert !(id(termination) in chain.blacklist) "identity already blacklisted" # delisted
    @assert issuer(termination) == chain.spec.registrar
    @assert verify(termination, crypto(chain.spec))

    push!(chain, termination)
    
    return length(chain)
end


#end
