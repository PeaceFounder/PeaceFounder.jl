module BraidChains

### I could define ledger here and delegate the constructor at PeaceFounder level.
using Sockets

import PeaceVote

using PeaceVote: voters!, Certificate, Intent, Contract, Consensus, Envelope, Notary, Deme, Signer, ID, DemeID, AbstractID, AbstractVote, AbstractProposal
using PeaceVote: record!, records, loadrecord
#using PeaceVote: verify


using ..Braiders: Braider
using ..Crypto
using ..DataFormat ### 
using ..Types: RecorderConfig, PFID, Proposal, Vote, Braid

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
