module BraidChains

### I could define ledger here and delegate the constructor at PeaceFounder level.
using Sockets

import PeaceVote
using PeaceVote: Proposal, Vote, Option, voters!, Certificate, Notary, Deme, Signer
using PeaceVote: record!, records, loadrecord

using ..Braiders: Braider
using ..Crypto
using ..DataFormat ### 
using ..Types: RecorderConfig

const ThisDeme = Deme

### The type should be defined here
# struct BraidChain
#     ledger::Ledger 
#     port # can be nothing but then one needs to have 
#     #cache
# end


include("../debug.jl")

#include("ledger.jl")
include("analysis.jl")
include("recorder.jl")

export register, vote, propose, count, BraidChain, RecorderConfig, Recorder

end
