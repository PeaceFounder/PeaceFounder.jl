using SynchronicBallot
using SecureIO

using PeaceVote: DemeSpec, Notary

### In future this will extend the method of synchronic ballot. Perhaps this could also be defined there.
function Mixer(port,notary::Notary,signer::Signer)
    mixergate = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))
    mixermember = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))
    #mixergate = SocketConfig(nothing,DH(wrap(signer),envelope->envelope,G,chash,()->rngint(100)),(socket,key)->SecureSocket(socket,key))
    #mixermember = SocketConfig(nothing,DH(wrap(signer),envelope->envelope,G,chash,() -> rngint(100)),(socket,key)->SecureSocket(socket,key))
    return BallotBox(port,mixergate,mixermember,randperm) # should be renamed to Mixer
end

### This is the level at which multiple braiders can be introduced.

struct Braider
    server
    voters::Set
end

import Base.take!
take!(braider::Braider) = take!(braider.server.ballots)


function Braider(braider::BraiderConfig,notary::Notary,signer::Signer)

    #systemconfig = SystemConfig(deme)
    #braider = systemconfig.braider
    #braider = BraiderConfig(deme) ### Need to implement

    voters = Set()

    mixeruuid = braider.mixerid[1]
    mixerid = braider.mixerid[2]

    # Hopefully this one works!!!
    mixerdemespec = DemeSpec(mixeruuid)
    mixernotary = Notary(mixerdemespec)
     

    gatemixer = SocketConfig(mixerid,DHasym(mixernotary),(socket,key)->SecureSocket(socket,key))
    gatemember =  SocketConfig(voters,DHsym(notary,signer),(socket,key)->SecureSocket(socket,key))

    #gatemember =  SocketConfig(voters,DH(wrap(signer),unwrap,G,chash,() -> rngint(100)),(socket,key)->SecureSocket(socket,key))

    server = GateKeeper(braider.port,braider.ballotport,braider.N,gatemixer,gatemember)
    Braider(server,voters)
end


function Braider(deme::ThisDeme,signer::Signer)
    systemconfig = SystemConfig(deme)
    braider = systemconfig.braider
    notary = deme.notary
    Braider(braider,notary,signer)
end


import PeaceVote.braid!
### Here one could use PeaceFounder to send stuff anonymously.
function braid!(config::BraiderConfig,notary::Notary,voter::Signer,signer::Signer)
    
    membergate = SocketConfig(config.gateid,DHsym(notary,signer),(socket,key)->SecureSocket(socket,key))
    #membergate = SocketConfig(config.gateid,DH(data->(data,signer.sign(data)),unwrap,G,chash,() -> rngint(100)),(socket,key)->SecureSocket(socket,key))

    mixeruuid = config.mixerid[1]
    mixerid = config.mixerid[2]

    ### Hopefully also this works
    mixerdemespec = DemeSpec(mixeruuid)
    mixernotary = Notary(mixerdemespec)

    #commod = community(mixeruuid)
    membermixer = SocketConfig(mixerid,DHasym(mixernotary),(socket,key)->SecureSocket(socket,key))

    #membermixer = SocketConfig(mixerid,DH(data->(data,nothing),commod.unwrap,commod.G,commod.chash,() -> rngint(100)),(socket,key)->commod.SecureSocket(socket,key))

    SynchronicBallot.vote(config.port,membergate,membermixer,voter.id,x->sign(x,signer))
end

function braid!(deme::ThisDeme,voter::Signer,signer::Signer)
    systemconfig = SystemConfig(deme)
    config = sytemconfig.braider
    notary = deme.notary
    braid!(config,notary,voter,signer)
end
