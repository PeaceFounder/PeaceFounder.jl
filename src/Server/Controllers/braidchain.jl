#module BraidChainController

# This module defines BraidChain with the focus of exposing it to the Mapper layer and offering it's incremental state updates
# with the record! function. For the sake of simplicity all controllers may be combined under a single module Controllers.

using Base: UUID
using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof
using Dates: DateTime
using ..Core.Model: Pseudonym, Transaction, DemeSpec, Generator, Commit, ChainState, Signer, Membership, Proposal, BraidReceipt, Digest, hasher, digest, id, seal, pseudonym, crypto, verify, input_generator, input_members, output_generator, output_members, BraidChainLedger
using ..Core.ProtocolSchema: AckInclusion, AckConsistency

import ..Core.Model: isbinding, generator, members, voters
#import ..LedgerInterface: record!, commit!, ack_leaf, ack_root, commit_index, reset_tree!, root, commit, select, state, leaf

"""
    struct BraidChain
        members::Set{Pseudonym}
        ledger::Vector{Transaction}
        spec::DemeSpec
        generator::Generator
        tree::HistoryTree
        commit::Union{Commit{ChainState}, Nothing}
    end

Represents a braidchain ledger with it's associated state. Can be instantitated with a demespec file using
`BraidChain(::DemeSpec)` method.

**Interface:**  [`push!`](@ref), [`record!`](@ref), [`state`](@ref), [`length`](@ref), [`list`](@ref), [`select`](@ref), [`roll`](@ref), [`constituents`](@ref), [`generator`](@ref), [`commit`](@ref), [`commit_index`](@ref), [`ledger`](@ref), [`leaf`](@ref), [`root`](@ref), [`ack_leaf`](@ref), [`ack_root`](@ref), [`members`](@ref), [`commit!`](@ref)
"""
mutable struct BraidChain
    members::Set{Pseudonym}
    #ledger::Vector{Transaction}
    ledger::BraidChainLedger
    spec::DemeSpec
    generator::Generator
    tree::HistoryTree
    commit::Union{Commit{ChainState}, Nothing}
end


function print_vector(io::IO, vector::Vector)
    
    for i in vector
        println(io, show_string(i))
    end
    
end


function Base.show(io::IO, chain::BraidChain)

    println(io, "BraidChain:")
    println(io, "  members : $(length(chain.members)) entries")
    println(io, "  generator : $(string(chain.generator))")
    println(io, "  guardian : $(string(issuer(spec)))")
    println(io, "  recorder : $(string(chain.spec.recorder))")
    println(io, "")
    #println(io, show_string(chain.ledger))
    print_vector(io, chain.ledger.records)
    println(io, "")
    print(io, show_string(chain.commit))

end


function BraidChain(spec::DemeSpec) 
    
    chain = BraidChain(Set{Pseudonym}(), BraidChainLedger(Transaction[]), spec, generator(spec), HistoryTree(Digest, hasher(spec)), nothing)
    # 
    # push!(chain, spec) 

    return chain
end
    

function record!(chain::BraidChain, spec::DemeSpec)

    @assert length(chain.ledger) == 0 "Reinitialization not yet implemented"

    push!(chain, spec)
    
    N = length(chain)

    return N
end


"""
    reset_tree!(ledger::BraidChain)

Recompute a chain tree hash. 
"""
function reset_tree!(chain::BraidChain)

    d = Digest[digest(i, hasher(chain.crypto)) for i in chain.ledger]
    tree = HistoryTree(d, hasher(chain.crypto))

    chain.tree = tree

    return
end

"""
    push!(ledger::BraidChain, t::Transaction)

Add an element to the BraidChain bypassing transaction verification with the chain.
This should only be used when the ledger is loaded from a trusted source like
a local disk or when final root hash is validated with a trusted source.
"""
function Base.push!(chain::BraidChain, t::Transaction)
    push!(chain.ledger, t)
    #push!(chain.tree, digest(t, crypto(chain)))
    push!(chain.tree, digest(t, hasher(chain.spec)))
    return
end

Base.length(chain::BraidChain) = length(chain.ledger)

"""
    list(T, ledger::BraidChain)::Vector{Tuple{Int, T}}

List braidchain elements with a given type together with their index.
"""
list(::Type{T}, chain::BraidChain) where T <: Transaction = ((n,p) for (n,p) in enumerate(chain.ledger) if p isa T)

# list also accpets filter arguments. 
"""
    select(T, predicate::Function, ledger::BraidChain)::Union{T, Nothing}

Return a first element from a ledger with a type `T` which satisfies a predicate. 
"""
function select(::Type{T}, f::Function, chain::BraidChain) where T <: Transaction

    for i in chain.ledger
        if i isa T && f(i)
            return i
        end
    end

    return nothing
end


"""
    roll(ledger::BraidChain)::Vector{Membership}

Return all member certificates from a braidchain ledger.
"""
roll(chain::BraidChain) = (m for m in chain.ledger if m isa Membership)

"""
    constituents(ledger::BraidChain)::Set{Pseudonym}

Return all member identity pseudonyms. 
"""
constituents(chain::BraidChain) = Set(id(i) for i in roll(chain))

"""
    generator(ledger::BraidChain)

Return a current relative generator for a braidchain ledger.
"""
generator(chain::BraidChain) = chain.generator

"""
    commit(ledger::BraidChain)

Return a current commit for a braichain. 
"""
commit(chain::BraidChain) = chain.commit

commit_index(chain::BraidChain) = index(commit(chain))


ledger(chain::BraidChain) = chain.ledger

"""
    leaf(ledger::BraidChain, N::Int)::Digest

Return a ledger's element digest at given index.
"""
leaf(chain::BraidChain, N::Int) = leaf(chain.tree, N)

"""
    root(ledger::BraidChain[, N::Int])::Digest

Return a ledger root digest. In case when index is not given a current index is used.
"""
root(chain::BraidChain) = root(chain.tree)
root(chain::BraidChain, N::Int) = root(chain.tree, N)


Base.getindex(chain::BraidChain, n::Int) = chain.ledger[n]

"""
    ack_leaf(ledger::BraidChain, index::Int)::AckInclusion

Return a proof for record inclusion with respect to a current braidchain ledger history tree root. 
"""
function ack_leaf(chain::BraidChain, index::Int) 

    @assert commit_index(chain) >= index
    
    proof = InclusionProof(chain.tree, index)
    
    return AckInclusion(proof, commit(chain))
end

"""
    ack_root(ledger::BraidChain, index::Int)

Return a proof for the ledger root at given index with respect to the current braidchain ledger history tree root.
"""
function ack_root(chain::BraidChain, index::Int) 
    
    @assert commit_index(chain) >= index
    
    proof = ConsistencyProof(chain.tree, index)
    
    return AckConsistency(proof, commit(chain))
end


"""
    generator(ledger[, index])

Return a generator at braidchain ledger row index. If `index` is omitted return the current state value.
"""
function generator(chain::BraidChain, n::Int)
    
    for i in view(chain.ledger, n:-1:1) # I could also use a reverse there

        if i isa BraidReceipt
            return output_generator(i)
        end

    end

    return generator(chain.spec)
end


"""
    members(ledger::BraidChain[, index::Int])::Set{Pseudonym}

Return a set of member pseudonyms at relative generator at braidchain ledger row index.
If `index` is omitted return a current state value.
"""
function members(chain::BraidChain, n::Int)
    
    mset = Set{Pseudonym}()
    for i in view(chain.ledger, n:-1:1)

        if i isa Membership
            push!(mset, pseudonym(i))
        end
        
        if i isa BraidReceipt

            for j in output_members(i)
                push!(mset, j)
            end

            return mset
        end

    end

    return mset
end


members(chain::BraidChain) = chain.members

"""
    state(ledger::BraidChain)

Return a current braidchain ledger state metadata.
"""
state(chain::BraidChain) = ChainState(length(chain), root(chain), generator(chain), length(members(chain)))

state(chain::BraidChain, n::Int) = error("Not Implemented")


Base.findlast(::Type{T}, ledger::Vector{Transaction}) where T <: Transaction = findlast(x -> x isa T, ledger)
Base.findlast(::Type{T}, chain::BraidChain) where T <: Transaction = findlast(T, chain.ledger)


"""
    commit!(ledger::BraidChain, signer::Signer)

Commit a current braidchain ledger state with a signer's issued cryptographic signature. 
"""
function commit!(chain::BraidChain, signer::Signer) 

    @assert chain.spec.recorder == id(signer)

    _state = state(chain)
    chain.commit = Commit(_state, seal(_state, signer))

    return
end

members(chain::BraidChain, state::ChainState) = members(chain, state.index)

voters(chain::BraidChain, index::Int) = output_members(chain.ledger[index]::BraidReceipt)
voters(chain::BraidChain, state::ChainState) = voters(chain, state.index)



function Base.push!(chain::BraidChain, m::Membership)

    push!(chain.ledger, m)
    push!(chain.members, pseudonym(m))
    push!(chain.tree, digest(m, hasher(chain.spec)))
    
    return
end


function record!(chain::BraidChain, m::Membership)

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


function Base.push!(chain::BraidChain, braidwork::BraidReceipt)

    push!(chain.ledger, braidwork)
    push!(chain.tree, digest(braidwork, hasher(chain.spec)))

    chain.generator = output_generator(braidwork)
    chain.members = Set(output_members(braidwork))

    return
end


function record!(chain::BraidChain, braidwork::BraidReceipt)

    @assert generator(chain) == input_generator(braidwork)
    @assert members(chain) == Set(input_members(braidwork))

    @assert verify(braidwork, crypto(chain.spec)) "Braid is invalid"

    push!(chain, braidwork)

    return length(chain)
end


"""
    isbinding(chain::BraidChain, state::ChainState)::Bool

Check that chain state is consistent with braidchain ledger.
"""
isbinding(chain::BraidChain, state::ChainState) = root(chain, index(state)) == root(state) && generator(chain, index(state)) == generator(state)


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
    
    @assert chain.ledger[state(p).index] isa BraidReceipt "Proposals can only be anchored on braids." 

    push!(chain, p)

    N = length(chain)

    return N
end


# It could also throw an error 
#members(chain::BraidChain, proposal::Proposal) = members(chain, proposal.anchor)
voters(chain::BraidChain, proposal::Proposal) = voters(chain, proposal.anchor)

select(::Type{Proposal}, uuid::UUID, chain::BraidChain) = select(Proposal, x -> x.uuid == uuid, chain)


#end
