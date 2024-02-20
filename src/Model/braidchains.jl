using HistoryTrees: HistoryTree, InclusionProof, ConsistencyProof
using Base: UUID, @kwdef

"""
    Transaction

Represents an abstract record type which can be stored in the braidchain ledger. 
"""
abstract type Transaction end # an alternative name is Transaction

"""
    struct DemeSpec <: Transaction
        uuid::UUID
        title::String
        crypto::CryptoSpec
        guardian::Pseudonym
        recorder::Pseudonym
        registrar::Pseudonym
        braider::Pseudonym
        proposer::Pseudonym 
        collector::Pseudonym
        timestamp::Union{DateTime, Nothing} = nothing
        signature::Union{Signature, Nothing} = nothing
    end

Represents a deme configuration parameters issued by the guardian.

- `uuid::UUID` an unique random generated community identifier;
- `title::String` a community name with which deme is represented;
- `crypto::CryptoSpec` cryptographic parameters for the deme;
- `guardian::Pseudonym` an issuer for this demespec file. Has authorithy to set a roster:
    - `recorder::Pseudonym` an authorithy which has rights to add new transactions and is responsable for braidchain's ledger integrity. Issues `Commit{ChainState}`;
    - `registrar::Pseudonym` an authorithy which has rights to authorize new admissions to the deme. See [`Admission`](@ref) and [`MembershipCertificate`](@ref);
    - `braider::Pseudonym` an authorithy which can do a legitimate braid jobs for other demes. See [`BraidReceipt`](@ref);   
    - `proposer::Pseudonym` an authorithy which has rights to issue a proposals for the braidchain. See [`Proposal`](@ref);
    - `collector::Pseudonym` an authorithy which is repsonsable for collecting votes for proposals. This is also recorded in the proposal itself.
- `timestamp::Union{DateTime, Nothing}` time when signature is being issued;
- `signature::Union{Signature, Nothing}` a guardian issued signature. 
"""
@kwdef struct DemeSpec <: Transaction
    uuid::UUID
    title::String
    crypto::CryptoSpec

    guardian::Pseudonym
    recorder::Pseudonym
    registrar::Pseudonym
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
    println(io, "  registrar : $(string(deme.registrar))")
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

"""
    struct ChainState
        index::Int
        root::Digest
        generator::Generator
        member_count::Int
    end

Represents a chain state metadata which is sufficient for integrity checks.

**Interface:** [`index`](@ref), [`root`](@ref), [`generator`](@ref)
"""
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

"""
    isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::CryptoSpec)

A generic method checking whether transaction is included in the braidchain.
"""
isbinding(record::Transaction, ack::AckInclusion{ChainState}, crypto::CryptoSpec) = digest(record, crypto) == leaf(ack)

isbinding(record::Transaction, ack::AckInclusion{ChainState}, hasher::Hash) = digest(record, hasher) == leaf(ack)
isbinding(ack::AckInclusion{ChainState}, record::Transaction, hasher::Hash) = isbinding(record, ack, hasher)


isbinding(ack::AckInclusion{ChainState}, id::Pseudonym) = issuer(ack) == id

isbinding(ack::AckInclusion{ChainState}, deme::DemeSpec) = issuer(ack) == deme.recorder

isbinding(record::Transaction, ack::AckInclusion{ChainState}, deme::DemeSpec) = isbinding(ack, deme) && isbinding(record, ack, hasher(deme))


isbinding(commit::Commit{ChainState}, deme::DemeSpec) = issuer(commit) == deme.recorder


function Base.show(io::IO, state::ChainState)
    
    println(io, "ChainState:")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    println(io, "  generator : $(string(state.generator))")
    print(io, "  member_count : $(state.member_count)")
    
end

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
    roll(ledger::BraidChain)::Vector{MembershipCertificate}

Return all member certificates from a braidchain ledger.
"""
roll(chain::BraidChain) = (m for m in chain.ledger if m isa MembershipCertificate)

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
    
    for i in view(chain.ledger, n:-1:1)

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

        if i isa MembershipCertificate
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


"""
    struct TicketID
        id::Vector{UInt8}
    end

Represents a unique identifier for which a recruit tooken is issued. In case of necessity `id` can contain
a full document, for instance, registration form, proof of identity and etc. In case a privacy is an issue
the `id` can contain a unique identifier which can be matched to an identity in an external database.
"""
struct TicketID
    id::Vector{UInt8}
end


bytes(ticketid::TicketID) = ticketid.id
Base.bytes2hex(ticketid::TicketID) = bytes2hex(bytes(ticketid))

Base.:(==)(x::TicketID, y::TicketID) = x.id == y.id

TicketID(x::String) = TicketID(copy(Vector{UInt8}(x)))

"""
    struct Admission
        ticketid::TicketID
        id::Pseudonym
        timestamp::DateTime
        approval::Union{Seal, Nothing}
    end

Represents an admission certificate for a pseudonym `id`. 

**Interface:** [`approve`](@ref), [`issuer`](@ref), [`id`](@ref), [`ticket`](@ref), [`isadmitted`](@ref)
"""
struct Admission
    ticketid::TicketID # document on which basis registrar have decided to approve the member
    id::Pseudonym
    timestamp::DateTime # Timestamp could be used as a deadline
    approval::Union{Seal, Nothing}
    # demespec::Digest # To prevent malicios guardian to downgrade cryptographic parameters, set a selective route compromising anonimity. Uppon receiving admission member would test that demespec is the one as sent in the invite.  
end



Admission(ticketid::TicketID, id::Pseudonym, timestamp::DateTime) = Admission(ticketid, id, timestamp, nothing)

Base.:(==)(x::Admission, y::Admission) = x.ticketid == y.ticketid && x.id == y.id && x.timestamp == y.timestamp && x.approval == y.approval

"""
    isbinding(admission::Admission, spec::DemeSpec)

Check whether issuer of `admission` is a registrar set in `spec`.
"""
isbinding(admission::Admission, deme::DemeSpec) = issuer(admission) == deme.registrar


"""
    approve(x::T, signer::Signer)::T
    
Cryptographically sign a document `x::T` and returns a signed document with the same type. To check whether a document
is signed see `issuer` method.
"""
approve(admission::Admission, signer::Signer) = @set admission.approval = seal(admission, signer)

issuer(admission::Admission) = isnothing(admission.approval) ? nothing : pseudonym(admission.approval)

id(admission::Admission) = admission.id

"""
    ticket(x::Admission)

Return a TicketID which is admitted.
"""
ticket(admission::Admission) = admission.ticketid


function Base.show(io::IO, admission::Admission)
    
    println(io, "Admission:")
    println(io, "  ticket : $(string(admission.ticketid))")
    println(io, "  identity : $(string(admission.id))")
    println(io, "  timestamp : $(admission.timestamp)")
    print(io, "  issuer : $(string(issuer(admission)))")

end



"""
    struct MembershipCertificate <: Transaction
        admission::Admission
        generator::Generator
        pseudonym::Pseudonym
        approval::Union{Signature, Nothing} 
    end

A new member certificate which rolls in (anouances) it's `pseudonym` at current generator signed with identity pseudonym
certified with admission certificate issued by registrar. This two step process is necessary as a checkpoint in situations when 
braidchain ledger get's locked during a new member resgistration procedure.
"""
struct MembershipCertificate <: Transaction
    admission::Admission
    generator::Generator
    pseudonym::Pseudonym
    approval::Union{Signature, Nothing} # In principle it could also be a proof log_G(A) == log_Y(B)
end

MembershipCertificate(admission::Admission, generator::Generator, pseudonym::Pseudonym) = MembershipCertificate(admission, generator, pseudonym, nothing)


Base.:(==)(x::MembershipCertificate, y::MembershipCertificate) = x.admission == y.admission && x.generator == y.generator && x.pseudonym == y.pseudonym && x.approval == y.approval

"""
    approve(member::MembershipCertificate, signer::Signer)::MembershipCertificate

Sign a member certificate and return it with `approval` field filled.
"""
approve(member::MembershipCertificate, signer::Signer) = @set member.approval = sign(member, signer)

"""
    issuer(member::MembershipCertificate)::Pseudonym

The identiy of registrar who signed admission.
"""
issuer(member::MembershipCertificate) = issuer(member.admission)

"""
    id(member::MembershipCertificate)::Pseudonym

Identity pseudonym for a member. 
"""
id(member::MembershipCertificate) = id(member.admission)


"""
    pseudonym(member::MembershipCertificate)::Pseudonym

Pseudonym for a member at the `generator(member)`. 
"""
pseudonym(member::MembershipCertificate) = member.pseudonym


"""
    generator(member::MembershipCertificate)::Generator

Generator at which member tries to roll in the braidchain.
"""
generator(member::MembershipCertificate) = member.generator

"""
    ticket(member::MembershipCertificate)

Ticket for a member admission certificate.
"""
ticket(member::MembershipCertificate) = ticket(member.admission)

function Base.show(io::IO, member::MembershipCertificate)

    println(io, "MembershipCertificate:")
    println(io, "  issuer : $(string(issuer(member)))")
    println(io, "  ticket : $(string(ticket(member)))")
    println(io, "  identity : $(string(id(member)))")
    println(io, "  generator : $(string(generator(member)))")
    print(io, "  pseudonym : $(string(pseudonym(member)))")

end



function Base.push!(chain::BraidChain, m::MembershipCertificate)

    push!(chain.ledger, m)
    push!(chain.members, pseudonym(m))
    push!(chain.tree, digest(m, hasher(chain.spec)))
    
    return
end


function record!(chain::BraidChain, m::MembershipCertificate)

    N = findfirst(==(m), ledger(chain))
    !isnothing(N) && return N
    
    
    @assert generator(chain) == generator(m)
    @assert !(pseudonym(m) in members(chain))
    @assert pseudonym(m.admission.approval) == chain.spec.registrar

    @assert verify(m, crypto(chain.spec)) # verifies also admission 

    push!(chain, m)
    N = length(chain)

    return N
end
