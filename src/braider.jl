import SynchronicBallot
using SynchronicBallot: BallotBox, GateKeeper, SocketConfig
#using SecureIO
using PeaceVote: DemeSpec, Notary

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
take!(braider::Braider) = take!(braider.server.ballots)

function Braider(braider::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,signer::Signer) 

    voters = Set()

    mixerid = braider.mixerid[2]

    gatemixer = SocketConfig(mixerid,DHasym(mixerdeme.cypher,mixerdeme.notary),mixerdeme.cypher.secureio)
    gatemember =  SocketConfig(voters,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)

    server = GateKeeper(braider.port,braider.ballotport,braider.N,gatemixer,gatemember)
    Braider(server,voters)
end

# New in this context just overloads generated function since it is not necessary.
function Braider(braider::BraiderConfig,deme::ThisDeme,signer::Signer)
    mixeruuid = braider.mixerid[1]

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,nothing)
    
    Braider(braider,deme,mixerdeme,signer)
end


function Braider(deme::ThisDeme,signer::Signer)
    systemconfig = SystemConfig(deme) ### This is where the config file is verified
    braider = systemconfig.braider
    Braider(braider,deme,signer)
end

import PeaceVote.braid!

function braid!(config::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,voter::Signer,signer::Signer)
    mixerid = config.mixerid[2]
    
    membergate = SocketConfig(config.gateid,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)
    membermixer = SocketConfig(mixerid,DHasym(mixerdeme.cypher,mixerdeme.notary),deme.cypher.secureio)

    SynchronicBallot.vote(config.port,membergate,membermixer,voter.id,x->sign(x,signer))
end

function braid!(config::BraiderConfig,deme::ThisDeme,voter::Signer,signer::Signer)
    mixeruuid = config.mixerid[1]

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,nothing) 

    braid!(config,deme,mixerdeme,voter,signer)
end

function braid!(deme::ThisDeme,voter::Signer,signer::Signer)
    systemconfig = SystemConfig(deme)
    config = systemconfig.braider
    braid!(config,deme,voter,signer)
end
