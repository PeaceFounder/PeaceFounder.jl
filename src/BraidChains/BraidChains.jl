module BraidChains

using DemeNet: ID, Signer
using PeaceVote: KeyChain


include("Types/Types.jl")
include("Braiders/Braiders.jl")
include("Ledgers/Ledgers.jl") 
include("Recorders/Recorders.jl") 
include("Analysis/Analysis.jl") 

import .Types: BraidChain, Proposal, Vote
import .Braiders: braid!, BraiderConfig, Braider, Mixer
import .Recorders: RecorderConfig, Recorder, record
import .Ledgers: Ledger, record!, getrecord
import .Analysis: normalcount ### A counting strategy depends on the proposal, thus normalcount could be replaceed just with count



   
struct BraidChainConfig{T} # Perhaps BraidChainRemote
    server::ID
    mixerport::T
    syncport::T
    braider::BraiderConfig{T}
    recorder::RecorderConfig{T}
end

record(config::BraidChainConfig,data) = record(config.recorder,data)


struct BraidChainServer
    mixer
    synchronizer
    braider
    recorder
end

function BraidChainServer(config::BraidChainConfig,chain::BraidChain,server::Signer)
    
    mixer = Mixer(config.mixerport,chain.deme,server)
    synchronizer = @async Ledgers.serve(config.syncport,chain.ledger)
    braider = Braider(config.braider,chain.deme,server)
    recorder = Recorder(config.recorder,chain,braider,server)
    
    return BraidChainServer(mixer,synchronizer,braider,recorder)
end

import .Ledgers
import PeaceVote.Plugins: load
load(chain::BraidChain) = Ledgers.load(chain.ledger)

import PeaceVote.Plugins: sync!
sync!(deme::BraidChain,syncport) = Ledgers.sync!(deme.ledger,syncport)


import Base.count
count(index::Int,braidchain::BraidChain) = normalcount(index,braidchain)

import PeaceVote.Plugins: braid!
function braid!(config::BraidChainConfig,chain::BraidChain,kc::KeyChain)
    if length(kc.signers)==0 
        oldvoter = kc.member
    else
        oldvoter = kc.signers[end]
    end

    newvoter = Signer(kc.deme,kc.account * "/voters/$(string(oldvoter.id))")

    braid!(config.braider,chain.deme,newvoter,oldvoter)
    # if fails, delete the newvoter
    push!(kc.signers,newvoter)
end


end
