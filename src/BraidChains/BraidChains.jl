module BraidChains

### I could define ledger here and delegate the constructor at PeaceFounder level.
using Sockets
using Serialization
using Synchronizers: Ledger # I can use AbstractLedger from PeaceVote. On the other hand at the present stage I could leave such a raw dependencies until I gte everything up and running.


import PeaceVote
using PeaceVote: Proposal, Vote, Option, voters!, Certificate, Notary, Deme, Signer
using ..Braiders: Braider
using ..Crypto


const ThisDeme = Deme

struct BraidChainConfig
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

export register, vote, propose, count, braidchain, BraidChainConfig, BraidChainServer

end
