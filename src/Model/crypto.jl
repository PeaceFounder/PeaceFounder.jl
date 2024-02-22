using HistoryTrees: InclusionProof, ConsistencyProof
import HistoryTrees: leaf, root
using CryptoGroups: CryptoGroups, ECP, EC2N, Koblitz, MODP

import CryptoGroups
const GroupSpec = CryptoGroups.Spec # TODO: upstream the naming

import CryptoSignatures
import Nettle

import CryptoSignatures.DSA as Signature

index(proof::ConsistencyProof) = proof.index
index(proof::InclusionProof) = proof.index


"""
    struct Generator
        data::Vector{UInt8}
    end

Datatype which stores cryptogrpahic group point in standart octet form intended to be used as a base. See also `Pseudonym`.
"""
@struct_hash_equal struct Generator
    data::Vector{UInt8}
end

Generator(g::Generator) = g

#@batteries Generator

bytes(generator::Generator) = generator.data


"""
    struct Digest
        data::Vector{UInt8}
    end

A message digest obtained applying a hash function on a message or a document. See method [`digest`](@ref).
"""
struct Digest
    data::Vector{UInt8}
end

Digest() = Digest(UInt8[])

Base.:(==)(x::Digest, y::Digest) = x.data == y.data

bytes(digest::Digest) = digest.data



"""
    struct Hash
        spec::String
    end

A specification for a hasher. See method [`digest`](@ref).
"""
struct Hash # HashSpec?
    spec::String
end


Hash(hasher::Hash) = hasher

"""
    digest(bytes::Vector{UInt8}, hasher::Hash)::Digest
    digest(x, spec) = digest(canonicalize(x)::Vector{UInt8}, hasher(spec)::Hash)

Compute a hash digest. When input is not in bytes the [`canonicalize`](@ref) method is applied first.
"""
function digest(data::Vector{UInt8}, hasher::Hash)
    return Digest(Nettle.digest(hasher.spec, data))
end

(hasher::Hash)(x) = digest(x, hasher)
(hasher::Hash)(x, y) = digest(x, y, hasher)


"""
    isbinding(x, y, spec::Hash)::Bool
    isbinding(x, y, spec) = isbinding(x, y, hasher(spec)::Hash)

Check binding of two objects `x` and `y`. Some general examples:

- Check that a document is bound to it's signature. 
- Check that a record is included in the ledger.
- Check that a given object is consistent with a ledger.
"""
isbinding(x, y, hasher::Hash) = isbinding(y, x, hasher)::Bool # May not be clean enough
isbinding(x, y, spec) = isbinding(x, y, hasher(spec)::Hash)::Bool


"""
    generator(spec::Spec)::Generator

Return a generator of `spec`.

"""
function generator(spec::Union{ECP, EC2N, Koblitz})

    x, y = CryptoGroups.generator(spec)
    octet = CryptoGroups.octet(x, y, spec)

    return Generator(octet)
end

function generator(spec::MODP)

    g = CryptoGroups.generator(spec)
    octet = CryptoGroups.octet(g, spec)

    return Generator(octet)
end


function lower_groupspec(spec::Union{ECP, EC2N, Koblitz})
    
    ecname = CryptoGroups.Specs.names(spec)[1]
    
    return "EC: $ecname"
end

function lower_groupspec(spec::MODP)

    (; p, q, g) = spec

    return "MODP: $p, $q, $g"
end


function parse_groupspec(group_string::String)

    try
        head, body = split(group_string, ":")
        body_cleaned = replace(body, " "=> "")

        if head == "EC"

            return CryptoGroups.curve(body_cleaned)

        elseif head == "MODP"

            p_str, q_str, g_str = split(body_cleaned, ",")

            p = parse(BigInt, p_str)
            q = parse(BigInt, q_str)
            g = parse(BigInt, g_str)
            
            return MODP(;p, q, g)
        else
            error("Group with $head not implementeed")
        end

    catch
        error("Group string $group_string can't be parsed")
    end
end

_groupspec(spec::GroupSpec) = spec
_groupspec(spec::String) = parse_groupspec(spec)

"""
    struct CryptoSpec
        hasher::Hash
        group::GroupSpec
        generator::Generator
    end

Specification of cryptographic parameters which are used for public key cryptography, message hashing and authetification codes. 
"""
struct CryptoSpec
    hasher::Hash
    group::GroupSpec
    generator::Generator

    CryptoSpec(hash_spec, group_spec, generator) = new(Hash(hash_spec), _groupspec(group_spec), Generator(generator))

    function CryptoSpec(hash_spec, group_spec)
        spec = _groupspec(group_spec)
        return new(Hash(hash_spec), spec, generator(spec))
    end
end

#CryptoSpec(hash_spec::String, group_spec::String, generator::Vector{UInt8}) = CryptoSpec(Hash(hash_spec), group_spec, Generator(generator))
#CryptoSpec(hash_spec::String, group_spec::String, generator::Generator) = CryptoSpec(Hash(hash_spec), group_spec, generator)

#CryptoSpec(crypto::CryptoSpec, generator::Generator) = CryptoSpec(crypto.hasher, crypto.group, generator)
#CryptoSpec(hash_spec::String, group_spec::Spec) = CryptoSpec(hash_spec, group_spec, generator(group_spec))
#CryptoSpec(hash_spec::String, group_spec::Spec, generator::Vector{UInt8}) = CryptoSpec(hash_spec, group_spec, Generator(generator))


Base.:(==)(x::CryptoSpec, y::CryptoSpec) = x.hasher == y.hasher && x.group == y.group && x.generator == y.generator

"""
    generator(crypto::CryptoSpec)::Generator

Return a generator of the specification. 
"""
generator(crypto::CryptoSpec) = crypto.generator

hasher(crypto::CryptoSpec) = crypto.hasher

"""
    digest(message::Vector{UInt8}, hasher::Hash)::Digest
    digest(document, spec) = digest(canonicalize(message)::Vector{UInt8}, hasher(spec)::Hash)
    
Return a resulting digest applying hasher on the given message. When message is not octet string a `canonicalize` method is applied first.
"""
digest(x, crypto::CryptoSpec) = digest(x, hasher(crypto))
digest(x::Digest, y::Digest, crypto::CryptoSpec) = digest(x, y, hasher(crypto))

digest(x::Integer, hasher::Hash) = digest(collect(reinterpret(UInt8, [x])), hasher)


function Base.show(io::IO, spec::CryptoSpec)
    
    println(io, "CryptoSpec:")
    println(io, "  hasher : $(spec.hasher.spec)")
    println(io, "  group : $(spec.group)")
    print(io, "  generator : $(string(spec.generator))")

end

"""
    struct Pseudonym
        pk::Vector{UInt8}
    end

A datatype which stores public key in canonical standart octet form.
"""
@struct_hash_equal struct Pseudonym
    pk::Vector{UInt8}
end

#@batteries Pseudonym # treats as immutable; 

bytes(x::Pseudonym) = x.pk

Base.convert(::Type{Vector{UInt8}}, p::Pseudonym) = p.pk


base16encode(p::Pseudonym) = bytes2hex(convert(Vector{UInt8}, p))
base16decode(s::String) = hex2bytes(s)
base16decode(s::String, ::Type{Pseudonym}) = Pseudonym(base16decode(s))


attest(statement, witness) = isbinding(statement, witness) && verify(witness)

pseudonym(ctx::CryptoSignatures.DSAContext, generator::Generator, private_key::Integer) = Pseudonym(CryptoSignatures.public_key(ctx, generator.data, BigInt(private_key)))
pseudonym(ctx::CryptoSignatures.ECDSAContext, generator::Generator, private_key::Integer) = Pseudonym(CryptoSignatures.public_key(ctx, generator.data, BigInt(private_key); mode = :compressed))

pseudonym(p::CryptoGroups.PGroup) = Pseudonym(CryptoGroups.octet(p))
pseudonym(p::CryptoGroups.ECGroup) = Pseudonym(CryptoGroups.octet(p; mode = :compressed))

generator(g::CryptoGroups.Group) = Generator(CryptoGroups.octet(g))

#pseudonym(spec::CryptoSpec, generator::Generator, key::Integer) = Pseudonym(CryptoSignatures.public_key(_dsa_context(spec), generator.data, BigInt(key)))
pseudonym(spec::CryptoSpec, generator::Generator, key::Integer) = pseudonym(_dsa_context(spec), generator, key)
pseudonym(spec::CryptoSpec, key::Integer) = pseudonym(spec, generator(spec), key)


"""
    struct Signer
        spec::CryptoSpec
        pbkey::Pseudonym
        key::BigInt
    end

A signer type. See a method `generate(Signer, spec)` for initialization.

**Interface:** `pseudonym`, `id`, `sign`, `seal`, `approve`
"""
struct Signer
    spec::CryptoSpec
    pbkey::Pseudonym
    #key::Vector{UInt8}
    key::BigInt
end

Signer(spec::CryptoSpec, generator::Generator, key::Integer) = Signer(spec, pseudonym(spec, generator, key), key)
Signer(spec::CryptoSpec, key::Integer) = Signer(spec, generator(spec), key)

pseudonym(signer::Signer) = signer.pbkey
id(signer::Signer) = signer.pbkey

pseudonym(signer::Signer, generator::Generator) = pseudonym(signer.spec, generator, signer.key)

crypto(signer::Signer) = signer.spec
hasher(signer::Signer) = hasher(crypto(signer))

_dsa_context(spec::MODP, hasher::Union{String, Nothing}) = CryptoSignatures.DSAContext(spec, hasher)
_dsa_context(spec::Union{ECP, EC2N, Koblitz}, hasher::Union{String, Nothing}) = CryptoSignatures.ECDSAContext(spec, hasher)
_dsa_context(spec::GroupSpec, hasher::Hash) = _dsa_context(spec, hasher.spec)
_dsa_context(spec::CryptoSpec; hasher = spec.hasher) = _dsa_context(spec.group, hasher)


function keygen(spec::CryptoGroups.Spec, generator::Generator)

    order = CryptoGroups.order(spec)

    private_key = CryptoSignatures.generate_key(order)

    ctx = _dsa_context(spec, nothing)
    public_key = pseudonym(ctx, generator, private_key) # 

    return private_key, public_key
end


"""
    generate(Signer, spec::CryptoSpec)::Signer
    
Generate a unique private key and return a Signer object. 
"""
function generate(::Type{Signer}, spec::CryptoSpec)

    ctx = _dsa_context(spec)
    private_key = CryptoSignatures.generate_key(ctx)
    #public_key = CryptoSignatures.public_key(ctx, generator(spec).data, private_key)
    _pseudonym = pseudonym(ctx, generator(spec), private_key)
    
    return Signer(spec, _pseudonym, private_key)
end

"""
    sign(message::Vector{UInt8}[, generator::Generator], signer::Signer)::Signature

Sign a bytestring `message` with signer's private key and specification. When generator is provided it is used as 
a base for the signature.
"""
sign(message::Vector{UInt8}, generator::Generator, signer::Signer) = CryptoSignatures.sign(_dsa_context(signer.spec), message, generator.data, signer.key)
sign(message::Vector{UInt8}, signer::Signer) = sign(message, signer.spec.generator, signer)


"""
    sign(digest::Digest[, generator::Generator], signer::Signer)::Signature

Sign a digest as an integer with signer's private key and specification. This method avoids 
running hashing twice when that is done externally. When generator is provided it is used as 
a base for the signature.
"""
sign(digest::Digest, generator::Generator, signer::Signer) = CryptoSignatures.sign(_dsa_context(signer.spec; hasher = nothing), digest.data, generator, signer.key)
sign(digest::Digest, signer::Signer) = sign(digest, signer.spec.generator, signer)


function Base.show(io::IO, signer::Signer)

    println(io, "Signer:")
    println(io, "  identity : $(string(signer.pbkey))")
    print(io, show_string(signer.spec))

end


verify(message::Vector{UInt8}, pk::Pseudonym, signature::Signature, generator::Generator, spec::CryptoSpec) = CryptoSignatures.verify(_dsa_context(spec), message, generator.data, pk.pk, signature)
verify(message::Vector{UInt8}, pk::Pseudonym, signature::Signature, spec::CryptoSpec) = verify(message, pk, signature, spec.generator, spec)


verify(digest::Digest, pk::Pseudonym, signature::Signature, generator::Generator, spec::CryptoSpec) = CryptoSignatures.verify(_dsa_context(spec, hasher = nothing), digest.data, generator.data, pk.pk, signature)
verify(digest::Digest, pk::Pseudonym, signature::Signature, spec::CryptoSpec) = verify(digest, pk, signature, spec.generator, spec)

"""
    struct Seal
        pbkey::Pseudonym
        sig::Signature
    end

A wrapper type for a signature which adds a public key of signature issuer. See [`seal`](@ref) method. 

**Interface:** [`pseudonym`](@ref), [`verify`](@ref)
"""
struct Seal 
    pbkey::Pseudonym
    sig::Signature
end

Seal(id::Pseudonym, r, s) = Seal(id, Signature(r, s))

Base.:(==)(x::Seal, y::Seal) = x.pbkey == y.pbkey && x.sig == y.sig

pseudonym(seal::Seal) = seal.pbkey

"""
    seal(message::Vector{UInt8}[, generator::Generator], signer::Signer)::Seal

Sign a bytestring `message` with signer's private key and specification and return a signature as a `Seal`. When generator is provided it is used as 
a base for the signature. See also [`sign`](@ref).
"""
seal(message::Vector{UInt8}, signer::Signer) = Seal(signer.pbkey, sign(message, signer))
seal(message::Vector{UInt8}, generator::Generator, signer::Signer) = Seal(pseudonym(signer, generator), sign(message, generator, signer))


verify(message::Vector{UInt8}, seal::Seal, crypto::CryptoSpec) = verify(message, seal.pbkey, seal.sig, crypto)
verify(message::Vector{UInt8}, seal::Seal, generator::Generator, crypto::CryptoSpec) = verify(message, seal.pbkey, seal.sig, generator, crypto)

"""
    Commit{T}
        state::T
        seal::Seal
    end 

Represents a commited ledger state to which issuer can be held accountable for integrity. It is assumed that `T`
implements `index` and `root` necessaary to fix a ledger state. 

**Interface:** [`id`](@ref), [`issuer`](@ref), [`verify`](@ref), [`index`](@ref), [`root`](@ref), [`state`](@ref)
"""
@struct_hash_equal struct Commit{T}
    state::T
    seal::Seal
end

#@batteries Commit

id(commit::Commit) = pseudonym(commit.seal) # It is an id because of the context

"""
    issuer(x)

In case an object `x` is cryptographically signed return an issuer of who have issued the signature. See also [`id`](@ref).
"""
issuer(commit::Commit) = pseudonym(commit.seal) 

verify(commit::Commit, crypto::CryptoSpec) = verify(commit.state, commit.seal, crypto)

"""
    index(x)::Int

Return an index of a ledger state.
"""
index(commit::Commit) = index(commit.state)

"""
    root(x)::Digest

Return a ledger root hash.
"""
root(commit::Commit) = root(commit.state)

"""
    state(commit::Commit{T})::T

Return a ledger state. `T` implements `index` and `root`. 
"""
state(commit::Commit) = commit.state


function Base.show(io::IO, commit::Commit)

    println(io, "Commit:")
    println(io, show_string(commit.state))

    print(io, "  issuer : $(string(issuer(commit)))")
end


"""
    struct AckInclusion{T}
        proof::InclusionProof
        commit::Commit{T}
    end

Represents an acknowldgment from the issuer that a leaf is permanently included in the ledger. 
In case the ledger is tampered with this acknowledgement acts as sufficient proof to blame the issuer.

**Interface:** [`leaf`](@ref), [`id`](@ref), [`issuer`](@ref), [`commit`](@ref), [`index`](@ref), [`verify`](@ref)
"""
@struct_hash_equal struct AckInclusion{T}
    proof::InclusionProof
    commit::Commit{T}
end

#@batteries AckInclusion


function Base.show(io::IO, ack::AckInclusion)

    println(io, "AckInclusion:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end

"""
    leaf(ack::AckInclusion)

Access a leaf diggest for which the acknowledgment is made.
"""
leaf(ack::AckInclusion) = leaf(ack.proof)
id(ack::AckInclusion) = id(ack.commit)
issuer(ack::AckInclusion) = issuer(ack.commit)

"""
    index(ack::AckInclusion)::Int

Return an index at which the leaf is recorded in the ledger. To obtain the current ledger index use `index(commit(ack))`.
"""
index(ack::AckInclusion) = index(ack.proof)

"""
    commit(x)

Access a commit of an object `x`. 
"""
commit(ack::AckInclusion) = ack.commit
state(ack::AckInclusion) = state(ack.commit)


isbinding(proof::InclusionProof, commit::Commit, hasher::Hash) = HistoryTrees.verify(proof, root(commit), index(commit); hash = hasher)

#verify(ack::AckInclusion, crypto::CryptoSpec) = HistoryTrees.verify(ack.proof, root(ack.commit), index(ack.commit); hash = hasher(crypto)) && verify(commit(ack), crypto)
verify(ack::AckInclusion, crypto::CryptoSpec) = isbinding(ack.proof, ack.commit, crypto) && verify(commit(ack), crypto)

isbinding(ack::AckInclusion, id::Pseudonym) = issuer(ack) == id

"""
    struct AckConsistency{T}
        proof::ConsistencyProof
        commit::Commit{T}
    end

Represents an ackknowledgment from the issuer that a root is permanetly included in the ledger. This acknowledgemnt assures
that ledger up to `index(ack)` is included in the current ledger which has has index `index(commit(ack))`. This is useful in
a combination with `AckInclusion` to privatelly update it's validity rather than asking an explicit element. Also
ensures that other elements in the ledger are not being tampered with.

**Interface:** [`root`](@ref), [`id`](@ref), [`issuer`](@ref), [`commit`](@ref), [`index`](@ref), [`verify`](@ref)
"""
struct AckConsistency{T}
    proof::ConsistencyProof
    commit::Commit{T}
end

"""
    root(x::AckConsistency)

Access a root diggest for which the acknowledgment is made.
"""
root(ack::AckConsistency) = root(ack.proof)
id(ack::AckConsistency) = id(ack.commit)
issuer(ack::AckConsistency) = issuer(ack.commit)

commit(ack::AckConsistency) = ack.commit
state(ack::AckConsistency) = state(ack.commit)

isbinding(proof::ConsistencyProof, commit::Commit, hasher::Hash) = HistoryTrees.verify(proof, root(commit), index(commit); hash = hasher)

verify(ack::AckConsistency, crypto::CryptoSpec) = isbinding(ack.proof, ack.commit, crypto) && verify(commit(ack), crypto)

"""
    index(ack::AckConsistency)

Return an index for a root at which the consistency proof is made. To obtain the current ledger index use `index(commit(ack))`.

"""
index(ack::AckConsistency) = index(ack.proof)


function Base.show(io::IO, ack::AckConsistency)

    println(io, "AckConsistency:")
    println(io, show_string(ack.proof))
    print(io, show_string(ack.commit))

end

"""

    struct HMAC
        key::Vector{UInt8}
        hasher::Hash
    end

Represent a hash message authetification code authorizer.

**Interface:** [`hasher`](@ref), [`digest`](@ref), [`key`](@ref)
"""
struct HMAC
    key::Vector{UInt8}
    hasher::Hash
end

HMAC(key::Vector{UInt8}, hasher::String) = HMAC(key, Hash(hasher))

"""
    hasher(spec)::Hash

Access a hasher function from a given specification.
"""
hasher(hmac::HMAC) = hmac.hasher

digest(bytes::Vector{UInt8}, hmac::HMAC) = digest(UInt8[bytes..., hmac.key...], hasher(hmac))

"""
    key(x)

Access a secret key of an object `x`.
"""
key(hmac::HMAC) = hmac.key
