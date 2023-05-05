using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof
using Base: UUID, @kwdef


abstract type Transaction end # an alternative name is Transaction

@kwdef struct DemeSpec <: Transaction
    uuid::UUID
    title::String
    crypto::CryptoSpec

    guardian::Pseudonym
    recorder::Pseudonym
    recruiter::Pseudonym
    braider::Pseudonym
    proposer::Pseudonym 
    collector::Pseudonym

    timestamp::Union{DateTime, Nothing} = nothing

    # If an adversary can pinpoint the address from which a message was sent and its effect on the system, 
    # then they already know the contents of the message. Therefore, a TLS connection only marginally 
    # helps ensure the confidentiality of the cast vote. Phising and Tampering is dealt with signatures on tree roots and
    # data theft is nonissue as everything is public. 

    # cert::Nothing # An optional TLS certificate used for communication

    signature::Union{Signature, Nothing} = nothing
end

# Need to improve this
Base.:(==)(x::DemeSpec, y::DemeSpec) = x.uuid == y.uuid && x.title == y.title && x.guardian == y.guardian && x.crypto == y.crypto 

DemeSpec(title::String, guardian::Pseudonym, crypto::CryptoSpec) = DemeSpec(UUID(rand(1:10000)), title, guardian, crypto, nothing)

function Base.show(io::IO, deme::DemeSpec)

    println(io, "DemeSpec:")
    println(io, "  title : $(deme.title)")
    println(io, "  uuid : $(deme.uuid)")
    println(io, "  guardian : $(string(deme.guardian))")
    println(io, "  recorder : $(string(deme.recorder))")
    println(io, "  recruiter : $(string(deme.recruiter))")
    println(io, "  proposer : $(string(deme.proposer))")
    println(io, "  braider : $(string(deme.braider))")
    #println(io, "  cert : $(deme.cert)")
    print(io, show_string(deme.crypto))

end

crypto(deme::DemeSpec) = deme.crypto
hasher(deme::DemeSpec) = hasher(deme.crypto)


generator(spec::DemeSpec) = generator(crypto(spec))


isbinding(spec::DemeSpec, hash::Digest, hasher::Hash) = digest(spec, hasher) == hash
isbinding(spec::DemeSpec, hash::Vector{UInt8}, hasher::Hash) = isbinding(spec, Digest(hash), hasher)


@struct_hash_equal struct ChainState
    index::Int
    root::Digest
    generator::Generator
    member_count::Int
    #proot::Digest # Noinvasive way to make sure that every member get's the latest set of proposals.
end

ChainState(index::Int, root::Nothing, generator::Generator) = ChainState(index, Digest(), generator)

#@batteries ChainState

generator(state::ChainState) = state.generator
generator(commit::Commit{ChainState}) = generator(commit.state)

index(state::ChainState) = state.index
root(state::ChainState) = state.root

isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::CryptoSpec) = digest(record, crypto) == leaf(ack)

isbinding(record::Transaction, ack::AckInclusion{ChainState}, hasher::Hash) = digest(record, hasher) == leaf(ack)
isbinding(ack::AckInclusion{ChainState}, record::Transaction, hasher::Hash) = isbinding(record, ack, hasher)


isbinding(ack::AckInclusion{ChainState}, id::Pseudonym) = issuer(ack) == id

isbinding(ack::AckInclusion{ChainState}, deme::DemeSpec) = issuer(ack) == deme.recorder

isbinding(record::Transaction, ack::AckInclusion{ChainState}, deme::DemeSpec) = isbinding(ack, deme) && isbinding(record, ack, hasher(deme))

isbinding(admission::Admission, deme::DemeSpec) = issuer(admission) == deme.recruiter

isbinding(commit::Commit{ChainState}, deme::DemeSpec) = issuer(commit) == deme.recorder


function Base.show(io::IO, state::ChainState)
    
    println(io, "ChainState:")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    println(io, "  generator : $(string(state.generator))")
    print(io, "  member_count : $(state.member_count)")
    
end


mutable struct BraidChain
    members::Set{Pseudonym}
    ledger::Vector{Transaction}
    #crypto::CryptoSpec
    spec::DemeSpec
    generator::Generator
    #guardian::Pseudonym
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
    println(io, "  guardian : $(string(chain.spec.guardian))")
    println(io, "  recorder : $(string(chain.spec.recorder))")
    println(io, "")
    #println(io, show_string(chain.ledger))
    print_vector(io, chain.ledger)
    println(io, "")
    print(io, show_string(chain.commit))

end


#BraidChain(guardian::Pseudonym, crypto::CryptoSpec) = BraidChain(Set{Pseudonym}(), Transaction[], crypto, generator(crypto), guardian, HistoryTree(Digest, hasher(crypto)), nothing)

function BraidChain(spec::DemeSpec) 
    
    chain = BraidChain(Set{Pseudonym}(), Transaction[], spec, generator(spec), HistoryTree(Digest, hasher(spec)), nothing)
    push!(chain, spec)

    return chain
end
    


function reset_tree!(chain::BraidChain)

    d = Digest[digest(i, hasher(chain.crypto)) for i in chain.ledger]
    tree = HistoryTree(d, hasher(chain.crypto))

    chain.tree = tree

    return
end

function Base.push!(chain::BraidChain, t::Transaction)
    push!(chain.ledger, t)
    #push!(chain.tree, digest(t, crypto(chain)))
    push!(chain.tree, digest(t, hasher(chain.spec)))
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
    
    g = generator(chain.spec)
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


state(chain::BraidChain) = ChainState(length(chain), root(chain), generator(chain), length(members(chain)))


function commit!(chain::BraidChain, signer::Signer) 

    @assert chain.spec.recorder == id(signer)

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
    push!(chain.tree, digest(m, hasher(chain.spec)))
    
    return
end


function record!(chain::BraidChain, m::Member)

    N = findfirst(==(m), ledger(chain))
    !isnothing(N) && return N
    
    
    @assert generator(chain) == generator(m)
    @assert !(pseudonym(m) in members(chain))
    @assert pseudonym(m.admission.approval) == chain.spec.recruiter

    @assert verify(m, crypto(chain.spec)) # verifies also admission 

    push!(chain, m)
    N = length(chain)

    return N
end
