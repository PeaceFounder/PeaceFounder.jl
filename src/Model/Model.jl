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



struct Deme # I could also call it Deme. In app then list all votin contexts as demes
    uuid::UUID
    title::String
    description::String
    tally_trigger_delay::Union{Nothing, Int}
    guardian::Pseudonym
    seal::Union{Seal, Nothing}
end

# This one should be part of braidchain
# Can't be part of  the BraidChain as that would assume knowledge of the signers key




end
