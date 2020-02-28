using SynchronicBallot
using SecureIO
using PeaceVote: DemeSpec, Notary




### In future this will extend the method of synchronic ballot. Perhaps this could also be defined there.
function Mixer(port,notary::Notary,signer::Signer)
    mixergate = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))
    mixermember = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))

    return BallotBox(port,mixergate,mixermember,randperm) # should be renamed to Mixer
end

# SO the problem
Mixer(port,notary::NewNotary,signer::NewSigner) = invokelatest((notary,signer)->Mixer(port,notary,signer),unbox(notary),unbox(signer))

### This is the level at which multiple braiders can be introduced.

struct Braider
    server
    voters::Set
end

import Base.take!
take!(braider::Braider) = take!(braider.server.ballots)

function Braider(braider::BraiderConfig,notary::Notary,mixernotary::Notary,signer::Signer) 

    voters = Set()

    mixerid = braider.mixerid[2]

    gatemixer = SocketConfig(mixerid,DHasym(mixernotary),(socket,key)->SecureSocket(socket,key))
    gatemember =  SocketConfig(voters,DHsym(notary,signer),(socket,key)->SecureSocket(socket,key))

    server = GateKeeper(braider.port,braider.ballotport,braider.N,gatemixer,gatemember)
    Braider(server,voters)
end

Braider(braider::BraiderConfig,notary::NewNotary,mixernotary::NewNotary,signer::NewSigner) = invokelatest(Braider,braider,unbox(notary),unbox(mixernotary),unbox(signer))



function Braider(braider::BraiderConfig,notary::NewNotary,signer::NewSigner)
    mixeruuid = braider.mixerid[1]

    mixerdemespec = DemeSpec(mixeruuid)
    mixernotary = Notary(mixerdemespec)
    
    Braider(braider,notary,mixernotary,signer)
end


function Braider(deme::ThisDeme,signer::NewSigner)
    systemconfig = SystemConfig(deme) ### This is where the config file is verified
    braider = systemconfig.braider
    notary = deme.notary
    Braider(braider,notary,signer)
end

Braider(deme::New{ThisDeme},signer::NewSigner) = invokelatest(Braider,unbox(deme),unbox(signer))


import PeaceVote.braid!


function braid!(config::BraiderConfig,notary::Notary,mixernotary::Notary,voter::Signer,signer::Signer)
    mixerid = config.mixerid[2]
    
    membergate = SocketConfig(config.gateid,DHsym(notary,signer),(socket,key)->SecureSocket(socket,key))
    membermixer = SocketConfig(mixerid,DHasym(mixernotary),(socket,key)->SecureSocket(socket,key))

    SynchronicBallot.vote(config.port,membergate,membermixer,voter.id,x->sign(x,signer))
end

braid!(config::BraiderConfig,notary::NewNotary,mixernotary::NewNotary,voter::NewSigner,signer::NewSigner) = invokelatest(braid!,config,unbox(notary),unbox(mixernotary),unbox(voter),unbox(signer))

### Here one could use PeaceFounder to send stuff anonymously.
function braid!(config::BraiderConfig,notary::NewNotary,voter::NewSigner,signer::NewSigner)
    
    mixeruuid = config.mixerid[1]

    mixerdemespec = DemeSpec(mixeruuid)
    mixernotary = Notary(mixerdemespec) 

    braid!(config,notary,mixernotary,voter,signer)
end



function braid!(deme::ThisDeme,voter::Signer,signer::Signer)
    systemconfig = SystemConfig(deme)
    config = sytemconfig.braider
    notary = deme.notary
    braid!(config,notary,voter,signer)
end

### This method would be called by the test
braid!(deme::NewThisDeme,voter::NewSigner,signer::NewSigner) = invokelatest(braid!,unbox(deme),unbox(voter),unbox(signer))
