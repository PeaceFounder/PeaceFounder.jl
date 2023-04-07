using HistoryTrees: InclusionProof, ConsistencyProof
import HistoryTrees: leaf, root


index(proof::ConsistencyProof) = proof.index
index(proof::InclusionProof) = proof.index


struct Generator
    data::Vector{UInt8}
end

@batteries Generator

bytes(generator::Generator) = generator.data

struct Digest
    data::Vector{UInt8}
end

Digest() = Digest(UInt8[])

Base.:(==)(x::Digest, y::Digest) = x.data == y.data

bytes(digest::Digest) = digest.data

struct Hash # HashSpec?
    spec::String
end

(hasher::Hash)(x) = digest(x, hasher)
(hasher::Hash)(x, y) = digest(x, y, hasher)

struct CryptoSpec
    hasher::Hash
    group::String
    #generator::Vector{UInt8}
    generator::Generator
end

CryptoSpec(hash_spec::String, group_spec::String, generator::Vector{UInt8}) = CryptoSpec(Hash(hash_spec), group_spec, Generator(generator))
CryptoSpec(hash_spec::String, group_spec::String, generator::Generator) = CryptoSpec(Hash(hash_spec), group_spec, generator)
CryptoSpec(crypto::CryptoSpec, generator::Generator) = CryptoSpec(crypto.hasher, crypto.group, generator)

Base.:(==)(x::CryptoSpec, y::CryptoSpec) = x.hasher == y.hasher && x.group == y.group && x.generator == y.generator

generator(crypto::CryptoSpec) = crypto.generator

hasher(crypto::CryptoSpec) = crypto.hasher

digest(x, crypto::CryptoSpec) = digest(x, hasher(crypto))
digest(x::Digest, y::Digest, crypto::CryptoSpec) = digest(x, y, hasher(crypto))

digest(x::Integer, hasher::Hash) = digest(collect(reinterpret(UInt8, [x])), hasher)


function Base.show(io::IO, spec::CryptoSpec)
    
    println(io, "CryptoSpec:")
    println(io, "  hasher : $(spec.hasher.spec)")
    println(io, "  group : $(spec.group)")
    print(io, "  generator : $(string(spec.generator))")

end



struct Pseudonym
    pk::Vector{UInt8}
end

@batteries Pseudonym # treats as immutable; 

bytes(x::Pseudonym) = x.pk

Base.convert(::Type{Vector{UInt8}}, p::Pseudonym) = p.pk


base16encode(p::Pseudonym) = bytes2hex(convert(Vector{UInt8}, p))
base16decode(s::String) = hex2bytes(s)
base16decode(s::String, ::Type{Pseudonym}) = Pseudonym(base16decode(s))


attest(statement, witness) = isbinding(statement, witness) && verify(witness)



struct Signer
    spec::CryptoSpec
    pbkey::Pseudonym
    key::Vector{UInt8}
end

seq(signer::Signer, proposal::Digest) = 0 # 

pseudonym(signer::Signer) = signer.pbkey
id(signer::Signer) = signer.pbkey

pseudonym(signer::Signer, generator::Generator) = pseudonym(signer) # ToDo

crypto(signer::Signer) = signer.spec
hasher(signer::Signer) = hasher(crypto(signer))


function generate(::Type{Signer}, spec::CryptoSpec)
    return Signer(spec, Pseudonym(rand(UInt8, 4)), UInt8[1, 2, 3, 4])
end


sign(x::Vector{UInt8}, signer::Signer) = Signature(3454545, 23423424) # ToDo


sign(x::Vector{UInt8}, generator::Generator, signer::Signer) = Signature(3454545, 23423424) # ToDo


function Base.show(io::IO, signer::Signer)

    println(io, "Signer:")
    println(io, "  identity : $(string(signer.pbkey))")
    print(io, show_string(signer.spec))

end



struct Signature
    r::BigInt
    s::BigInt
end

Base.:(==)(x::Signature, y::Signature) = x.r == y.r && x.s == y.s

verify(x::Vector{UInt8}, pk::Pseudonym, signature::Signature, crypto::CryptoSpec) = true # ToDo

verify(x::Vector{UInt8}, pk::Pseudonym, signature::Signature, generator::Generator, crypto::CryptoSpec) = true # ToDo


struct Seal 
    pbkey::Pseudonym
    sig::Signature
end

Seal(id::Pseudonym, r, s) = Seal(id, Signature(r, s))

Base.:(==)(x::Seal, y::Seal) = x.pbkey == y.pbkey && x.sig == y.sig

pseudonym(seal::Seal) = seal.pbkey


verify(x::Vector{UInt8}, seal::Seal, crypto::CryptoSpec) = verify(x, seal.pbkey, seal.sig, crypto)

seal(x::Vector{UInt8}, signer::Signer) = Seal(signer.pbkey, sign(x, signer))


seal(x::Vector{UInt8}, generator::Generator, signer::Signer) = Seal(pseudonym(signer, generator), sign(x, generator, signer))

verify(x::Vector{UInt8}, seal::Seal, generator::Generator, crypto::CryptoSpec) = verify(x, seal.pbkey, seal.sig, generator, crypto)


struct Commit{T}
    state::T
    seal::Seal
end

@batteries Commit

id(commit::Commit) = pseudonym(commit.seal) # It is an id because of the context
issuer(commit::Commit) = pseudonym(commit.seal)

verify(commit::Commit, crypto::CryptoSpec) = verify(commit.state, commit.seal, crypto)

index(commit::Commit) = index(commit.state)

root(commit::Commit) = root(commit.state)
state(commit::Commit) = commit.state



function Base.show(io::IO, commit::Commit)

    println(io, "Commit:")
    println(io, show_string(commit.state))

    print(io, "  issuer : $(string(issuer(commit)))")
end


struct AckInclusion{T}
    proof::InclusionProof
    commit::Commit{T}
end

@batteries AckInclusion


function Base.show(io::IO, ack::AckInclusion)

    println(io, "AckInclusion:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end


#Base.:(==)(x::T, y::T) where T <: AckInclusion = 

leaf(ack::AckInclusion) = leaf(ack.proof)
id(ack::AckInclusion) = id(ack.commit)
issuer(ack::AckInclusion) = issuer(ack.commit)

index(ack::AckInclusion) = index(ack.proof)

commit(ack::AckInclusion) = ack.commit
state(ack::AckInclusion) = state(ack.commit)

verify(ack::AckInclusion, crypto::CryptoSpec) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)

isbinding(ack::AckInclusion, id::Pseudonym) = issuer(ack) == id

struct AckConsistency{T}
    proof::ConsistencyProof
    commit::Commit{T}
end

root(ack::AckConsistency) = root(ack.proof)
id(ack::AckConsistency) = id(ack.commit)
issuer(ack::AckConsistency) = issuer(ack.commit)

commit(ack::AckConsistency) = ack.commit
state(ack::AckConsistency) = state(ack.commit)

verify(ack::AckConsistency, crypto::CryptoSpec) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)

index(ack::AckConsistency) = index(ack.proof)


function Base.show(io::IO, ack::AckConsistency)

    println(io, "AckConsistency:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end


struct HMAC
    key::Vector{UInt8}
    hasher::Hash
end

hasher(hmac::HMAC) = hmac.hasher

digest(bytes::Vector{UInt8}, hmac::HMAC) = digest(UInt8[bytes..., hmac.key...], hasher(hmac))

key(hmac::HMAC) = hmac.key
