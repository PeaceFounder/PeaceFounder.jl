import HistoryTrees: leaf, root, HistoryTree
using CryptoGroups: CryptoGroups, ECP, EC2N, Koblitz, MODP, GroupSpec, HashSpec
using Dates: DateTime

import CryptoSignatures
import CryptoSignatures.DSA as Signature

"""
    struct Generator
        data::Vector{UInt8}
    end

Datatype which stores cryptogrpahic group point in standart octet form intended to be used as a base. See also `Pseudonym`.
"""
struct Generator
    data::Vector{UInt8}
end

@batteries Generator

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


HistoryTree(::Type{Digest}, hasher::HashSpec) = HistoryTree(Digest, (x, y) -> digest(x, y, hasher))
HistoryTree(d::Vector{Digest}, hasher::HashSpec) = HistoryTree(d, (x, y) -> digest(x, y, hasher))


"""
    digest(bytes::Vector{UInt8}, hasher::HashSpec)::Digest
    digest(x, spec) = digest(canonicalize(x)::Vector{UInt8}, hasher(spec)::HashSpec)

Compute a hash digest. When input is not in bytes the [`canonicalize`](@ref) method is applied first.
"""
function digest(data::Vector{UInt8}, hasher::HashSpec)
    return Digest(hasher(data))
end


"""
    isbinding(x, y, spec::HashSpec)::Bool
    isbinding(x, y, spec) = isbinding(x, y, hasher(spec)::HashSpec)

Check binding of two objects `x` and `y`. Some general examples:

- Check that a document is bound to it's signature. 
- Check that a record is included in the ledger.
- Check that a given object is consistent with a ledger.
"""
# Can't have both methods present
#isbinding(x, y, hasher::HashSpec) = isbinding(y, x, hasher)::Bool # May not be clean enough
isbinding(x, y, spec) = isbinding(x, y, hasher(spec)::HashSpec)::Bool


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
        hasher::HashSpec
        group::GroupSpec
        generator::Generator
    end

Specification of cryptographic parameters which are used for public key cryptography, message hashing and authetification codes. 
"""
struct CryptoSpec
    hasher::HashSpec
    group::GroupSpec
    generator::Generator

    CryptoSpec(hash_spec, group_spec, generator) = new(HashSpec(hash_spec), _groupspec(group_spec), Generator(generator))
    CryptoSpec(hash_spec::HashSpec, group_spec, generator) = new(hash_spec, _groupspec(group_spec), Generator(generator))

    function CryptoSpec(hash_spec, group_spec)
        spec = _groupspec(group_spec)
        return new(HashSpec(hash_spec), spec, generator(spec))
    end
end

Base.:(==)(x::CryptoSpec, y::CryptoSpec) = x.hasher == y.hasher && x.group == y.group && x.generator == y.generator

"""
    generator(crypto::CryptoSpec)::Generator

Return a generator of the specification. 
"""
generator(crypto::CryptoSpec) = crypto.generator

#hasher(spec::HashSpec) = spec
hasher(crypto::CryptoSpec) = crypto.hasher

"""
    digest(message::Vector{UInt8}, hasher::HashSpec)::Digest
    digest(document, spec) = digest(canonicalize(message)::Vector{UInt8}, hasher(spec)::HashSpec)
    
Return a resulting digest applying hasher on the given message. When message is not octet string a `canonicalize` method is applied first.
"""
digest(x, spec) = digest(x, hasher(spec))
digest(x::Digest, y::Digest, spec) = digest(x, y, hasher(spec))

digest(x::Integer, hasher::HashSpec) = digest(collect(reinterpret(UInt8, [x])), hasher)


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
struct Pseudonym
    pk::Vector{UInt8}
end

@batteries Pseudonym

# This is needed internally for easy grouping of the votes
function Base.isless(a::Pseudonym, b::Pseudonym)
    
    len_a = length(a.pk)
    len_b = length(b.pk)
    minlen = min(len_a, len_b)

    for i in 1:minlen
        if a.pk[i] != b.pk[i]
            return a.pk[i] < b.pk[i]
        end
    end

    return len_a < len_b
end


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
_dsa_context(spec::GroupSpec, hasher::HashSpec) = _dsa_context(spec, hasher.spec)
_dsa_context(spec::CryptoSpec; hasher = spec.hasher) = _dsa_context(spec.group, hasher)


function keygen(spec::GroupSpec, generator::Generator)

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
    timestamp::DateTime
    sig::Signature
end

#Seal(id::Pseudonym, r, s) = Seal(id, Signature(r, s))

Base.:(==)(x::Seal, y::Seal) = x.pbkey == y.pbkey && x.sig == y.sig

pseudonym(seal::Seal) = seal.pbkey


function epoch(timestamp::DateTime)

    period = timestamp - DateTime(1970, 1, 1)
    msec = Dates.value(period)

    return reinterpret(UInt8, [msec])
end


"""
    seal(message::Vector{UInt8}[, generator::Generator], signer::Signer)::Seal

Sign a bytestring `message` with signer's private key and specification and return a signature as a `Seal`. When generator is provided it is used as 
a base for the signature. See also [`sign`](@ref).
"""
function seal(message::Vector{UInt8}, signer::Signer; timestamp::Union{DateTime, Nothing} = nothing) 

    if isnothing(timestamp) 
        timestamp = Dates.now()
    end

    return Seal(signer.pbkey, timestamp, sign([epoch(timestamp)..., message...], signer))
end


function seal(message::Vector{UInt8}, generator::Generator, signer::Signer; timestamp::Union{DateTime, Nothing} = nothing)

    if isnothing(timestamp) 
        timestamp = Dates.now()
    end
    
    return Seal(pseudonym(signer, generator), timestamp, sign([epoch(timestamp)..., message...], generator, signer))
end

# Let's see what fails
verify(message::Vector{UInt8}, seal::Seal, crypto::CryptoSpec) = verify([epoch(seal.timestamp)..., message...], seal.pbkey, seal.sig, crypto)
verify(message::Vector{UInt8}, seal::Seal, generator::Generator, crypto::CryptoSpec) = verify([epoch(seal.timestamp)..., message...], seal.pbkey, seal.sig, generator, crypto)

"""
    Commit{T}
        state::T
        seal::Seal
    end 

Represents a commited ledger state to which issuer can be held accountable for integrity. It is assumed that `T`
implements `index` and `root` necessaary to fix a ledger state. 

**Interface:** [`id`](@ref), [`issuer`](@ref), [`verify`](@ref), [`index`](@ref), [`root`](@ref), [`state`](@ref)
"""
struct Commit{T}
    state::T
    seal::Seal
end

@batteries Commit

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

    struct HMAC
        key::Vector{UInt8}
        hasher::HashSpec
    end

Represent a hash message authetification code authorizer.

**Interface:** [`hasher`](@ref), [`digest`](@ref), [`key`](@ref)
"""
struct HMAC
    key::Vector{UInt8}
    hasher::HashSpec
end

HMAC(key::Vector{UInt8}, hasher::String) = HMAC(key, HashSpec(hasher))

"""
    hasher(spec)::HashSpec

Access a hasher function from a given specification.
"""
hasher(hmac::HMAC) = hmac.hasher

digest(bytes::Vector{UInt8}, hmac::HMAC) = digest(UInt8[bytes..., hmac.key...], hasher(hmac))

"""
    key(x)

Access a secret key of an object `x`.
"""
key(hmac::HMAC) = hmac.key
