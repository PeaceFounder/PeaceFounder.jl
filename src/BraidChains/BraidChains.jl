module BraidChains

### I could define ledger here and delegate the constructor at PeaceFounder level.
using Sockets

import PeaceVote
using PeaceVote: Proposal, Vote, Option, voters!, Certificate, Notary, Deme, Signer
using PeaceVote: record!, records, loadrecord

using ..Braiders: Braider
using ..Crypto
using ..DataFormat ### 

const ThisDeme = Deme

### The type should be defined here
# struct BraidChain
#     ledger::Ledger 
#     port # can be nothing but then one needs to have 
#     #cache
# end

struct RecorderConfig
    maintainerid # The one which signs the config file
    membersca ### One needs to explicitly add the certifier server id here. That's because 
    serverid
    registratorport ### The port to which the certificate of membership is delivered
    votingport
    proposalport
end

include("../debug.jl")

#include("ledger.jl")
include("analysis.jl")
include("recorder.jl")

export register, vote, propose, count, BraidChain, RecorderConfig, Recorder

end
