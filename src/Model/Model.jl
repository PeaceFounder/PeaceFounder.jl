module Model
# All interesting stuff

# A patch to Base. An alternative is to patch JSON3.jl 

using StructEquality

#using StructHelpers

using JSON3, StructTypes # used temporaraly for canonicalize

using Nettle
using Dates
using Setfield

using HistoryTrees

#using Infiltrator

# Proposals and Braids can be treated the same way as they are in a blockchain as proofs of work.



"""
    verify(message, seal::Seal, [generator::Generator], crypto::CryptoSpec)::Bool
    verify(message, pk::Pseudonym, sig::Signature, [generator::Generator], crypto::CryptoSpec)::Bool

Verify the cryptographic signature of the `message` returning `true` if valid. 
An optional `generator` can be given when signature is issued on 
a relative generator differing from a base specification `crypto`. 

--- 

    verify(document[, generator::Generator], crypto::CryptoSpec)::Bool

Verify a cryptographic signature of the `document` returning `true` if valid. 

--- 
        
    verify(braidwork::BraidWork, crypto::CryptoSpec)::Bool

Verify a braider issued cryptographic signature for the `braidwork` and a zero knowledge proofs.
Returns true if both checks succeed.

"""
function verify end


"""
    id(document)::Pseudonym

Return identity pseudonym of a `document` issuer.

---

    id(signer)::Pseudonym

Return identity pseudonym of a `signer`.
"""
function id end

"""
    pseudonym(signer::Signer, [generator])::Pseudonym

Return a pseudonym of a `signer` at a given relative `generator`. If generator is not passed returns identity pseudonym. (See also `id`)

---

    pseudonym(seal::Seal)::Pseudonym

Return a pseudonym of a seal. Note that it is not equal to identity when the signature is issued on a relative generator.

--- 

    pseudonym(vote::Vote)::Pseudonym

Return a pseudonym used to seal the vote.

"""
function pseudonym end

# I could implement that in the library
using HistoryTrees: InclusionProof, ConsistencyProof

Base.hash(proof::InclusionProof, h::UInt) = struct_hash(proof, h)
Base.hash(proof::ConsistencyProof, h::UInt) = struct_hash(proof, h)

Base.:(==)(a::InclusionProof, b::InclusionProof) = struct_equal(a, b)
Base.:(==)(a::ConsistencyProof, b::ConsistencyProof) = struct_equal(a, b)

#@batteries InclusionProof
#@batteries ConsistencyProof

# Note that admission is within a member as it's necessary to 


function Base.show(io::IO, proof::InclusionProof)

    println(io, "InclusionProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  leaf : $(string(proof.leaf))")
    print(io, "  path : $([string(i) for i in proof.path])")

end

function Base.show(io::IO, proof::ConsistencyProof)

    println(io, "ConsistencyProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  root : $(string(proof.root))")
    print(io, "  path : $([string(i) for i in proof.path])")

end


function show_string(x)

    buffer = IOBuffer()
    show(buffer, x)
    str = String(take!(buffer))
    
    indended_str = "  " * join(split(str, "\n"), "\n  ")

    return indended_str
end


include("crypto.jl")
include("admissions.jl")
include("braidchains.jl")
include("proposals.jl")
include("dealer.jl")
include("braids.jl")
include("seal.jl") # Defines how values should be canonicalized. Could contain means for a signer with a state.


export isbinding, braid, approve, verify, canonicalize

end
