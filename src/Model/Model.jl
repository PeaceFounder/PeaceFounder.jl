module Model
# All interesting stuff

# A patch to Base. An alternative is to patch JSON3.jl 

using JSON3, StructTypes # used temporaraly for canonicalize

using Nettle
using Dates
using Setfield

using HistoryTrees

using Infiltrator

# Proposals and Braids can be treated the same way as they are in a blockchain as proofs of work.




# Note that admission is within a member as it's necessary to 


include("crypto.jl")
include("admissions.jl")
include("braidchains.jl")
include("proposals.jl")
include("dealer.jl")
include("braids.jl")
include("seal.jl") # Defines how values should be canonicalized. Could contain means for a signer with a state.



struct Deme
    uuid::UUID
    title::String
    guardian::Pseudonym
    crypto::Crypto
    cert # TLS certificate used for communication
    #seal::Union{Seal, Nothing}
end


Deme(title::String, guardian::Pseudonym, crypto::Crypto) = Deme(UUID(rand(1:10000)), title, guardian, crypto, nothing)

hasher(deme::Deme) = hasher(deme.crypto)


end
