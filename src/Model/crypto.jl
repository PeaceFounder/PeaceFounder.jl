using HistoryTrees: InclusionProof, ConsistencyProof
import HistoryTrees: leaf, root


struct Digest
    data::Vector{UInt8}
end

Digest() = Digest(UInt8[])

Base.:(==)(x::Digest, y::Digest) = x.data == y.data


struct Hash 
    spec::String
end

(hasher::Hash)(x) = digest(x, hasher)
(hasher::Hash)(x, y) = digest(x, y, hasher)

struct Crypto
    hasher::Hash
    group
    generator::Vector{UInt8}
end

Crypto(hash_spec::String, group_spec::String, generator::Vector{UInt8}) = Crypto(Hash(hash_spec), group_spec, generator)

Crypto(crypto::Crypto, generator::Vector{UInt8}) = Crypto(crypto.hasher, crypto.group, generator)

generator(crypto::Crypto) = crypto.generator

hasher(crypto::Crypto) = crypto.hasher

digest(x, crypto::Crypto) = digest(x, hasher(crypto))
digest(x::Digest, y::Digest, crypto::Crypto) = digest(x, y, hasher(crypto))

digest(x::Integer, hasher::Hash) = digest(collect(reinterpret(UInt8, [x])), hasher)



struct Pseudonym
    pk::Vector{UInt8}
end

bytes(x::Pseudonym) = x.pk

Base.:(==)(x::Pseudonym, y::Pseudonym) = x.pk == y.pk

Base.convert(::Type{Vector{UInt8}}, p::Pseudonym) = p.pk


base16encode(p::Pseudonym) = bytes2hex(convert(Vector{UInt8}, p))
base16decode(s::String) = hex2bytes(s)
base16decode(s::String, ::Type{Pseudonym}) = Pseudonym(base16decode(s))


attest(statement, witness) = isbinding(statement, witness) && verify(witness)



struct Signer
    spec::Crypto
    pbkey::Pseudonym
    key::Vector{UInt8}
end

seq(signer::Signer, proposal::Digest) = 0 # 

pseudonym(signer::Signer) = signer.pbkey
id(signer::Signer) = signer.pbkey

pseudonym(signer::Signer, generator::Vector{UInt8}) = pseudonym(signer) # ToDo

function gen_signer(crypto::Crypto) 
    return Signer(crypto, Pseudonym(rand(UInt8, 4)), UInt8[1, 2, 3, 4])
end


sign(x::Vector{UInt8}, signer::Signer) = Signature(3454545, 23423424) # ToDo


sign(x::Vector{UInt8}, generator::Vector{UInt8}, signer::Signer) = Signature(3454545, 23423424) # ToDo


struct Signature
    r::BigInt
    s::BigInt
end

Base.:(==)(x::Signature, y::Signature) = x.r == y.r && x.s == y.s

verify(x::Vector{UInt8}, pk::Pseudonym, signature::Signature, crypto::Crypto) = true # ToDo

verify(x::Vector{UInt8}, pk::Pseudonym, signature::Signature, generator::Vector{UInt8}, crypto::Crypto) = true # ToDo


# Approval
# Stamp
# Seal
struct Seal
    pbkey::Pseudonym
    sig::Signature
end

Base.:(==)(x::Seal, y::Seal) = x.pbkey == y.pbkey && x.sig == y.sig

pseudonym(seal::Seal) = seal.pbkey


verify(x::Vector{UInt8}, seal::Seal, crypto::Crypto) = verify(x, seal.pbkey, seal.sig, crypto)

seal(x::Vector{UInt8}, signer::Signer) = Seal(signer.pbkey, sign(x, signer))


seal(x::Vector{UInt8}, generator::Vector{UInt8}, signer::Signer) = Seal(pseudonym(signer, generator), sign(x, generator, signer))

verify(x::Vector{UInt8}, seal::Seal, generator::Vector{UInt8}, crypto::Crypto) = verify(x, seal.pbkey, seal.sig, generator, crypto)


struct Commit{T}
    state::T
    seal::Seal
end

id(commit::Commit) = pseudonym(commit.seal) # It is an id because of the context

verify(commit::Commit, crypto::Crypto) = verify(commit.state, commit.seal, crypto)

index(commit::Commit) = index(commit.state)

root(commit::Commit) = root(commit.state)
state(commit::Commit) = commit.state

struct AckInclusion{T}
    proof::InclusionProof
    commit::Commit{T}
end

leaf(ack::AckInclusion) = leaf(ack.proof)
id(ack::AckInclusion) = id(ack.commit)

commit(ack::AckInclusion) = ack.commit

verify(ack::AckInclusion, crypto::Crypto) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)


struct AckConsistency{T}
    proof::ConsistencyProof
    commit::Commit{T}
end

root(ack::AckConsistency) = root(ack.root)
id(ack::AckConsistency) = id(ack.commit)

commit(ack::AckConsistency) = ack.commit

verify(ack::AckConsistency, crypto::Crypto) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)
