using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof


abstract type Transaction end # an alternative name is Transaction

struct ChainState
    index::Int
    root::Digest
    generator::Generator
    #proot::Digest # Noinvasive way to make sure that every member get's the latest set of proposals.
end

ChainState(index::Int, root::Nothing, generator::Generator) = ChainState(index, Digest(), generator)

@batteries ChainState

generator(state::ChainState) = state.generator
generator(commit::Commit{ChainState}) = generator(commit.state)

index(state::ChainState) = state.index
root(state::ChainState) = state.root

isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::Crypto) = digest(record, crypto) == leaf(ack)

isbinding(record::Transaction, ack::AckInclusion{ChainState}, hasher::Hash) = digest(record, hasher) == leaf(ack)
isbinding(ack::AckInclusion{ChainState}, record::Transaction, hasher::Hash) = isbinding(record, ack, hasher)


isbinding(ack::AckInclusion{ChainState}, id::Pseudonym) = issuer(ack) == id




function Base.show(io::IO, state::ChainState)
    
    println(io, "ChainState:")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    print(io, "  generator : $(string(state.generator))")
    
end




mutable struct BraidChain
    members::Set{Pseudonym}
    ledger::Vector{Transaction}
    crypto::Crypto
    generator::Generator
    guardian::Pseudonym
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
    println(io, "  guardian : $(string(chain.guardian))")
    println(io, "")
    #println(io, show_string(chain.ledger))
    print_vector(io, chain.ledger)
    println(io, "")
    print(io, show_string(chain.commit))

end



BraidChain(guardian::Pseudonym, crypto::Crypto) = BraidChain(Set{Pseudonym}(), Transaction[], crypto, generator(crypto), guardian, HistoryTree(Digest, hasher(crypto)), nothing)

function Base.push!(chain::BraidChain, t::Transaction)
    push!(chain.ledger, t)
    push!(chain.tree, digest(t, chain.crypto))
    return
end

Base.length(chain::BraidChain) = length(chain.ledger)


list(::Type{T}, chain::BraidChain) where T <: Transaction = ((n,p) for (n,p) in enumerate(chain.ledger) if p isa T)

# list also accpets filter arguments. 

function select(::Type{T}, f::Function, chain::BraidChain) where T <: Transaction

    for i in chain.ledger
        if i isa T && f(i)
            return i
        end
    end

    return nothing
end


#roll(chain::BraidChain) = (m for m in chain.ledger if m isa Member)
roll(chain::BraidChain) = (m for m in chain.ledger if m isa Member)

constituents(chain::BraidChain) = Set(id(i) for i in roll(chain))

generator(chain::BraidChain) = chain.generator

commit(chain::BraidChain) = chain.commit

commit_index(chain::BraidChain) = index(commit(chain))


ledger(chain::BraidChain) = chain.ledger


leaf(chain::BraidChain, N::Int) = leaf(chain.tree, N)

root(chain::BraidChain) = root(chain.tree)
root(chain::BraidChain, N::Int) = root(chain.tree, N)


Base.getindex(chain::BraidChain, n::Int) = chain.ledger[n]


function ack_leaf(chain::BraidChain, index::Int) 

    @assert commit_index(chain) >= index
    
    proof = InclusionProof(chain.tree, index)
    
    return AckInclusion(proof, commit(chain))
end


function ack_root(chain::BraidChain, index::Int) 
    
    @assert commit_index(chain) >= index
    
    proof = ConsistencyProof(chain.tree, index)
    
    return AckConsistency(proof, commit(chain))
end



function generator(chain::BraidChain, n::Int)
    
    g = generator(chain.crypto)
    for i in view(chain.ledger, 1:n)
        # only braid can make a change here. 
    end

    return g
end


function members(chain::BraidChain, n::Int)
    
    set = Set{Pseudonym}()
    for i in view(chain.ledger, 1:n)
        if i isa Member
            push!(set, pseudonym(i))
        end
        
        # braids also need to be treated here
    end

    return set
end


members(chain::BraidChain) = chain.members



state(chain::BraidChain) = ChainState(length(chain), root(chain), generator(chain))


function commit!(chain::BraidChain, signer::Signer) 

    _state = state(chain)
    chain.commit = Commit(_state, seal(_state, signer))

    return
end

members(chain::BraidChain, state::ChainState) = members(chain, state.index)

struct Member <: Transaction
    admission::Admission
    generator::Generator
    pseudonym::Pseudonym
    approval::Union{Signature, Nothing} # In principle it could also be a proof log_G(A) == log_Y(B)
end

Member(admission::Admission, generator::Generator, pseudonym::Pseudonym) = Member(admission, generator, pseudonym, nothing)


Base.:(==)(x::Member, y::Member) = x.admission == y.admission && x.generator == y.generator && x.pseudonym == y.pseudonym && x.approval == y.approval

approve(member::Member, signer::Signer) = @set member.approval = sign(member, signer)

issuer(member::Member) = issuer(member.admission)

id(member::Member) = id(member.admission)

pseudonym(member::Member) = member.pseudonym

generator(member::Member) = member.generator

ticket(member::Member) = ticket(member.admission)

function Base.show(io::IO, member::Member)

    println(io, "Member:")
    println(io, "  issuer : $(string(issuer(member)))")
    println(io, "  ticket : $(string(ticket(member)))")
    println(io, "  identity : $(string(id(member)))")
    println(io, "  generator : $(string(generator(member)))")
    print(io, "  pseudonym : $(string(pseudonym(member)))")

end





function Base.push!(chain::BraidChain, m::Member)

    push!(chain.ledger, m)
    push!(chain.members, pseudonym(m))
    push!(chain.tree, digest(m, chain.crypto))
    
    return
end


function record!(chain::BraidChain, m::Member)

    N = findfirst(==(m), ledger(chain))
    !isnothing(N) && return N
    
    
    @assert generator(chain) == generator(m)
    @assert !(pseudonym(m) in members(chain))
    @assert pseudonym(m.admission.approval) == chain.guardian

    @assert verify(m, chain.crypto) # verifies also admission 

    push!(chain, m)
    N = length(chain)

    return N
end
