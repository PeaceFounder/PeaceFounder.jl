module Model
# All interesting stuff

# A patch to Base. An alternative is to patch JSON3.jl 

using StructEquality


using JSON3, StructTypes # used temporaraly for canonicalize

using Nettle
using Dates
using Setfield

using HistoryTrees



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
        
    verify(braidwork::BraidReceipt, crypto::CryptoSpec)::Bool

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


# Theese functions will be defined on the archive eventually 
function select end 
function members end 
function state end

function voters end # this is somewhat not part of the model either. perhaps I could provide a method for alias

# alias(votes, chain)::Vector{Int} # returns integers representing every vote
# alias(vote, chain)::Union{Int, Nothing}
# alias(pseudonym, proposal, chain)::Union{Int, Nothing}
# alias(psuedonym, bbox)::Union{Int, Nothing}
# alias(vote, bbox)::Union{Int, Nothing}
# alias(receipt) # this is how client could retrieve it


function commit end # may be deprecated as it is too similar to commit!


function show_string(x)

    buffer = IOBuffer()
    show(buffer, x)
    str = String(take!(buffer))
    
    indended_str = "  " * join(split(str, "\n"), "\n  ")

    return indended_str
end


include("crypto.jl")
include("braidchains.jl")
include("braids.jl") # reordered
include("proposals.jl")
include("seal.jl") # Defines how values should be canonicalized. Could contain means for a signer with a state.


export isbinding, braid, approve, verify, canonicalize

end
