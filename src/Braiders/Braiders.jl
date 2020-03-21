module Braiders

using ..Crypto

import SynchronicBallot
using SynchronicBallot: BallotBox, GateKeeper, SocketConfig
#using SecureIO
using PeaceVote: DemeSpec, Notary, Cypher, Signer, Deme, Contract, ID, DemeID

using ..Types: BraiderConfig, Braid

#include("crypto.jl") ### I can make a module Utils so to import thoose things here

#### SOME TEMPORARY FIXES ######

const ThisDeme = Deme

import PeaceVote
function PeaceVote.Consensus(braid::Contract{Braid},notary::Notary)
    refs = ID[]
    for s in braid.signatures
        id = verify(braid.document.ids,s,notary) ### Should be notary.verify("$(braid.document)",s) 
        push!(refs,id)
    end
    return PeaceVote.Consensus(braid.document,refs)
end

###############################


# I could substitute a sortperm to avoid this dependancy
using Random: randperm

### In future this will extend the method of synchronic ballot. Perhaps this could also be defined there.
function Mixer(port,cypher::Cypher,notary::Notary,signer::Signer)
    mixergate = SocketConfig(nothing,DHasym(cypher,notary,signer),cypher.secureio)
    mixermember = SocketConfig(nothing,DHasym(cypher,notary,signer),cypher.secureio)

    return BallotBox(port,mixergate,mixermember,randperm) # should be renamed to Mixer
end

Mixer(port,deme::ThisDeme,signer::Signer) = Mixer(port,deme.cypher,deme.notary,signer)

struct Braider
    server
    voters::Set
end

import Base.take!

function take!(braider::Braider) 
    msgs,signatures = take!(braider.server.ballots)
    braid = Braid(nothing,nothing,msgs)
    signedbraid = Contract(braid,signatures)
    return signedbraid
end

function Braider(braider::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,signer::Signer) 

    voters = Set()

    #mixerid = ID(braider.mixerid.id) ### That may mean I need DemeID contain ID instead of BigInt. 

    gatemixer = SocketConfig(braider.mixerid.id,DHasym(mixerdeme.cypher,mixerdeme.notary),mixerdeme.cypher.secureio)
    gatemember =  SocketConfig(voters,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)

    server = GateKeeper(braider.port,braider.ballotport,braider.N,gatemixer,gatemember)
    Braider(server,voters)
end

# New in this context just overloads generated function since it is not necessary.
function Braider(braider::BraiderConfig,deme::ThisDeme,signer::Signer)
    mixeruuid = braider.mixerid.uuid

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,ledger=false)
    
    Braider(braider,deme,mixerdeme,signer)
end


function Braider(deme::ThisDeme,signer::Signer)
    systemconfig = SystemConfig(deme) ### This is where the config file is verified
    braider = systemconfig.braider
    Braider(braider,deme,signer)
end

import PeaceVote.braid!

function braid!(config::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,voter::Signer,signer::Signer)
    
    membergate = SocketConfig(config.gateid,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)
    membermixer = SocketConfig(config.mixerid.id,DHasym(mixerdeme.cypher,mixerdeme.notary),deme.cypher.secureio)

    ### I need to take out a validate function, to check the braid formed by the server 
    # (1) That would check whether the message is in the braid
    # (2) The hash of the full ledger
    # (3) Some other metadata. Whether the same port was used by everyone to form the braid as well the same mixer and server. 

    SynchronicBallot.vote(config.port,membergate,membermixer,voter.id,x->sign(x,signer))
end

function braid!(config::BraiderConfig,deme::ThisDeme,voter::Signer,signer::Signer)
    mixeruuid = config.mixerid.uuid

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,ledger=false) 

    braid!(config,deme,mixerdeme,voter,signer)
end

function braid!(deme::ThisDeme,voter::Signer,signer::Signer)
    systemconfig = SystemConfig(deme)
    config = systemconfig.braider
    braid!(config,deme,voter,signer)
end

export Mixer, Braider, BraiderConfig, braid!

end # module


### The benefit would be that I would be able to expose the correct API
