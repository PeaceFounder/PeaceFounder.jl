using HistoryTrees: HistoryTrees, HistoryTree
using Base: UUID, @kwdef

"""
    Transaction

Represents an abstract record type which can be stored in the braidchain ledger. 
"""
abstract type Transaction end # an alternative name is Transaction

struct BraidChainLedger
    records::AbstractVector{Transaction}
end

BraidChainLedger() = BraidChainLedger(Transaction[])

@batteries BraidChainLedger

Base.push!(ledger::BraidChainLedger, record::Transaction) = push!(ledger.records, record)
Base.getindex(ledger::BraidChainLedger, index::Int) = ledger.records[index]
Base.length(ledger::BraidChainLedger) = length(ledger.records)
Base.findfirst(f::Function, ledger::BraidChainLedger) = findfirst(f, ledger.records) # 

Base.iterate(ledger::BraidChainLedger) = iterate(ledger.records)
Base.iterate(ledger::BraidChainLedger, index) = iterate(ledger.records, index)

Base.view(ledger::BraidChainLedger, args) = BraidChainLedger(view(ledger.records, args))


"""
    members(ledger::BraidChainLedger[, index::Int])::Set{Pseudonym}

Return a set of member pseudonyms at relative generator at braidchain ledger row index.
If `index` is omitted return a current state value.
"""
function members(ledger::BraidChainLedger, n::Int)
    
    mset = Set{Pseudonym}()
    for i in view(ledger, n:-1:1)

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

members(ledger::BraidChainLedger) = members(ledger, length(ledger))

voters(ledger::BraidChainLedger, index::Int) = output_members(ledger[index]::BraidReceipt)
voters(ledger::BraidChainLedger, state) = voters(ledger, index(state)::Int)


function root(ledger::BraidChainLedger, N::Int)

    spec::DemeSpec = ledger[1]
    
    leafs = Digest[]

    for record in view(ledger, 1:N)
        push!(leafs, digest(record, hasher(spec)))
    end

    # 
    tree = HistoryTree(leafs, hasher(spec)) # this executes tree hash directly
    return HistoryTrees.root(tree)
end

root(ledger::BraidChainLedger) = root(ledger, length(ledger))


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
    - `registrar::Pseudonym` an authorithy which has rights to authorize new admissions to the deme. See [`Admission`](@ref) and [`Membership`](@ref);
    - `braider::Pseudonym` an authorithy which can do a legitimate braid jobs for other demes. See [`BraidReceipt`](@ref);   
    - `proposer::Pseudonym` an authorithy which has rights to issue a proposals for the braidchain. See [`Proposal`](@ref);
    - `collector::Pseudonym` an authorithy which is repsonsable for collecting votes for proposals. This is also recorded in the proposal itself.
- `timestamp::Union{DateTime, Nothing}` time when signature is being issued;
- `signature::Union{Signature, Nothing}` a guardian issued signature. 
"""
@kwdef struct DemeSpec <: Transaction
    uuid::UUID
    title::String
    email::String
    crypto::CryptoSpec
    recorder::Pseudonym
    registrar::Pseudonym
    braider::Pseudonym
    proposer::Pseudonym 
    collector::Pseudonym

    # If an adversary can pinpoint the address from which a message was sent and its effect on the system, 
    # then they already know the contents of the message. Therefore, a TLS connection only marginally 
    # helps ensure the confidentiality of the cast vote. Phising and Tampering is dealt with signatures on tree roots and
    # data theft is nonissue as everything is public. 
    # cert::Nothing # An optional TLS certificate used for communication

    seal::Union{Seal, Nothing} = nothing
end

# Need to improve this
Base.:(==)(x::DemeSpec, y::DemeSpec) = x.uuid == y.uuid && x.title == y.title && x.email == y.email && x.crypto == y.crypto 

#DemeSpec(title::String, email::String, crypto::CryptoSpec) = DemeSpec(UUID(rand(1:10000)), title, email, crypto, nothing)

issuer(spec::DemeSpec) = pseudonym(spec.seal)

function Base.show(io::IO, deme::DemeSpec)

    println(io, "DemeSpec:")
    println(io, "  title : $(deme.title)")
    println(io, "  email : $(deme.email)")
    println(io, "  uuid : $(deme.uuid)")
    println(io, "  guardian : $(string(issuer(deme)))")
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


isbinding(spec::DemeSpec, hash::Digest, hasher::HashSpec) = digest(spec, hasher) == hash
isbinding(spec::DemeSpec, hash::Vector{UInt8}, hasher::HashSpec) = isbinding(spec, Digest(hash), hasher)


verify(x, spec::DemeSpec) = verify(x, spec.crypto)
verify(x, y, spec::DemeSpec) = verify(x, y, spec.crypto)
verify(x, y, z, spec::DemeSpec) = verify(x, y, z, spec.crypto)
verify(x, y, z, w, spec::DemeSpec) = verify(x, y, z, w, spec.crypto)

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
struct ChainState
    index::Int
    root::Digest
    generator::Generator
    member_count::Int
    #proot::Digest # Noinvasive way to make sure that every member get's the latest set of proposals.
end

ChainState(index::Int, root::Nothing, generator::Generator) = ChainState(index, Digest(), generator)

@batteries ChainState

generator(state::ChainState) = state.generator
generator(commit::Commit{ChainState}) = generator(commit.state)

index(state::ChainState) = state.index
root(state::ChainState) = state.root


isbinding(commit::Commit{ChainState}, deme::DemeSpec) = issuer(commit) == deme.recorder


function Base.show(io::IO, state::ChainState)
    
    println(io, "ChainState:")
    println(io, "  index : $(state.index)")
    println(io, "  root : $(string(state.root))")
    println(io, "  generator : $(string(state.generator))")
    print(io, "  member_count : $(state.member_count)")
    
end


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

**Interface:** [`approve`](@ref), [`issuer`](@ref), [`id`](@ref), [`ticket`](@ref), [`isadmitted`]
"""
struct Admission
    ticketid::TicketID # document on which basis registrar have decided to approve the member
    id::Pseudonym
    seal::Union{Seal, Nothing}
    # demespec::Digest # To prevent malicios guardian to downgrade cryptographic parameters, set a selective route compromising anonimity. Uppon receiving admission member would test that demespec is the one as sent in the invite. 
end


Admission(ticketid::TicketID, id::Pseudonym) = Admission(ticketid, id, nothing)

Base.:(==)(x::Admission, y::Admission) = x.ticketid == y.ticketid && x.id == y.id && x.seal == y.seal

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
approve(admission::Admission, signer::Signer) = @set admission.seal = seal(admission, signer)

issuer(admission::Admission) = isnothing(admission.seal) ? nothing : pseudonym(admission.seal)

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
    println(io, "  timestamp : $(admission.seal.timestamp)")
    print(io, "  issuer : $(string(issuer(admission)))")

end



"""
    struct Membership <: Transaction
        admission::Admission
        generator::Generator
        pseudonym::Pseudonym
        approval::Union{Signature, Nothing} 
    end

A new member certificate which rolls in (anouances) it's `pseudonym` at current generator signed with identity pseudonym
certified with admission certificate issued by registrar. This two step process is necessary as a checkpoint in situations when 
braidchain ledger get's locked during a new member resgistration procedure.
"""
struct Membership <: Transaction
    admission::Admission
    generator::Generator
    pseudonym::Pseudonym
    approval::Union{Signature, Nothing} # In principle it could also be a proof log_G(A) == log_Y(B)
end

Membership(admission::Admission, generator::Generator, pseudonym::Pseudonym) = Membership(admission, generator, pseudonym, nothing)


Base.:(==)(x::Membership, y::Membership) = x.admission == y.admission && x.generator == y.generator && x.pseudonym == y.pseudonym && x.approval == y.approval

"""
    approve(member::Membership, signer::Signer)::Membership

Sign a member certificate and return it with `approval` field filled.
"""
approve(member::Membership, signer::Signer) = @set member.approval = sign(member, signer)

"""
    issuer(member::Membership)::Pseudonym

The identiy of registrar who signed admission.
"""
issuer(member::Membership) = issuer(member.admission)

"""
    id(member::Membership)::Pseudonym

Identity pseudonym for a member. 
"""
id(member::Membership) = id(member.admission)


"""
    pseudonym(member::Membership)::Pseudonym

Pseudonym for a member at the `generator(member)`. 
"""
pseudonym(member::Membership) = member.pseudonym


"""
    generator(member::Membership)::Generator

Generator at which member tries to roll in the braidchain.
"""
generator(member::Membership) = member.generator

"""
    ticket(member::Membership)

Ticket for a member admission certificate.
"""
ticket(member::Membership) = ticket(member.admission)

function Base.show(io::IO, member::Membership)

    println(io, "Membership:")
    println(io, "  issuer : $(string(issuer(member)))")
    println(io, "  ticket : $(string(ticket(member)))")
    println(io, "  identity : $(string(id(member)))")
    println(io, "  generator : $(string(generator(member)))")
    print(io, "  pseudonym : $(string(pseudonym(member)))")

end
