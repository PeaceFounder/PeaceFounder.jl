#module BraidChainController

# This module defines BraidChainController with the focus of exposing it to the Mapper layer and offering it's incremental state updates
# with the record! function. For the sake of simplicity all controllers may be combined under a single module Controllers.

using Base: UUID
using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof
using Dates: DateTime
using ..Core.Model: Pseudonym, Transaction, DemeSpec, Generator, Commit, ChainState, Signer, Membership, Proposal, BraidReceipt, Digest, hasher, digest, id, seal, pseudonym, crypto, verify, input_generator, input_members, output_generator, output_members, BraidChainLedger, issuer, show_string
using ..Core.ProtocolSchema: AckInclusion, AckConsistency

import ..Core.Model: isbinding, generator, members, voters

# struct BraidBroker end # ToDo


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

**Interface:**  [`push!`](@ref), [`record!`](@ref), [`state`](@ref), [`length`](@ref), [`list`](@ref), [`select`](@ref), [`roll`](@ref), [`constituents`](@ref), [`generator`](@ref), [`commit`](@ref), [`commit_index`](@ref), [`ledger`](@ref), [`leaf`](@ref), [`root`](@ref), [`ack_leaf`](@ref), [`ack_root`](@ref), [`members`](@ref), [`commit!`](@ref)
"""
mutable struct BraidChainController
    members::Set{Pseudonym}
    ledger::BraidChainLedger
    spec::DemeSpec
    generator::Generator
    tree::HistoryTree
    commit::Union{Commit{ChainState}, Nothing}
end


function BraidChainController(spec::DemeSpec) 
    
    chain = BraidChainController(Set{Pseudonym}(), BraidChainLedger(Transaction[]), spec, generator(spec), HistoryTree(Digest, hasher(spec)), nothing)

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

    chain = BraidChainController(_members, ledger, spec, _generator, tree, commit)
    
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

"""
    push!(ledger::BraidChainController, t::Transaction)

Add an element to the BraidChainController bypassing transaction verification with the chain.
This should only be used when the ledger is loaded from a trusted source like
a local disk or when final root hash is validated with a trusted source.
"""
function Base.push!(chain::BraidChainController, t::Transaction)
    push!(chain.ledger, t)
    push!(chain.tree, digest(t, hasher(chain.spec)))
    return
end

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


"""
    roll(ledger::BraidChainController)::Vector{Membership}

Return all member certificates from a braidchain ledger.
"""
roll(chain::BraidChainController) = (m for m in chain.ledger if m isa Membership)

"""
    constituents(ledger::BraidChainController)::Set{Pseudonym}

Return all member identity pseudonyms. 
"""
constituents(chain::BraidChainController) = Set(id(i) for i in roll(chain))

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

members(chain::BraidChainController, n::Int) = members(chain.ledger, n)
members(chain::BraidChainController, state::ChainState) = members(chain, state.index)
members(chain::BraidChainController) = chain.members

voters(chain::BraidChainController, anchor) = voters(ledger(chain), anchor)

"""
    state(ledger::BraidChainController)

Return a current braidchain ledger state metadata.
"""
state(chain::BraidChainController) = ChainState(length(chain), root(chain), generator(chain), length(members(chain)))

state(chain::BraidChainController, n::Int) = error("Not Implemented")


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

    push!(chain.ledger, m)
    push!(chain.members, pseudonym(m))
    push!(chain.tree, digest(m, hasher(chain.spec)))
    
    return
end

function record!(chain::BraidChainController, m::Membership)

    N = findfirst(==(m), ledger(chain))
    !isnothing(N) && return N

    @assert generator(chain) == generator(m)
    @assert !(pseudonym(m) in members(chain))
    @assert pseudonym(m.admission.seal) == chain.spec.registrar

    @assert verify(m, crypto(chain.spec)) # verifies also admission 

    push!(chain, m)
    N = length(chain)

    return N
end

function Base.push!(chain::BraidChainController, braidwork::BraidReceipt)

    push!(chain.ledger, braidwork)
    push!(chain.tree, digest(braidwork, hasher(chain.spec)))
    chain.generator = output_generator(braidwork)
    chain.members = Set(output_members(braidwork))

    return
end

function record!(chain::BraidChainController, braidwork::BraidReceipt)

    @assert generator(chain) == input_generator(braidwork)
    @assert members(chain) == Set(input_members(braidwork))

    @assert verify(braidwork, crypto(chain.spec)) "Braid is invalid"

    push!(chain, braidwork)

    return length(chain)
end


"""
    isbinding(chain::BraidChainController, state::ChainState)::Bool

Check that chain state is consistent with braidchain ledger.
"""
isbinding(chain::BraidChainController, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)


function Base.push!(chain::BraidChainController, p::Proposal)
    push!(chain.ledger, p)
    push!(chain.tree, digest(p, hasher(chain.spec)))
    return
end


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
    @assert verify(p, crypto(chain.spec))
    
    @assert chain.ledger[state(p).index] isa BraidReceipt "Proposals can only be anchored on braids." 

    push!(chain, p)

    N = length(chain)

    return N
end


select(::Type{Proposal}, uuid::UUID, chain::BraidChainController) = select(Proposal, x -> x.uuid == uuid, chain)

#end
