using SynchronicBallot
using SecureIO
using PeaceVote: DemeSpec, Notary, New

### In future this will extend the method of synchronic ballot. Perhaps this could also be defined there.
function Mixer(port,notary::Notary,signer::Signer)
    mixergate = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))
    mixermember = SocketConfig(nothing,DHasym(notary,signer),(socket,key)->SecureSocket(socket,key))

    return BallotBox(port,mixergate,mixermember,randperm) # should be renamed to Mixer
end

# SO the problem
#Mixer(port,notary::New[Notary],signer::New[Signer]) = invokelatest((notary,signer)->Mixer(port,notary,signer),unbox(notary),unbox(signer))

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

#Braider(braider::BraiderConfig,notary::New[Notary],mixernotary::New[Notary],signer::New[Signer]) = invokelatest(Braider,braider,unbox(notary),unbox(mixernotary),unbox(signer))

# New in this context just overloads generated function since it is not necessary.
function Braider(braider::BraiderConfig,notary::New[Notary],signer::New[Signer])
    mixeruuid = braider.mixerid[1]

    mixerdemespec = DemeSpec(mixeruuid)
    mixernotary = Notary(mixerdemespec)
    
    Braider(braider,notary,mixernotary,signer)
end


function Braider(deme::ThisDeme,signer::New[Signer])
    systemconfig = SystemConfig(deme) ### This is where the config file is verified
    braider = systemconfig.braider
    notary = deme.notary
    Braider(braider,notary,signer)
end

#Braider(deme::New{ThisDeme},signer::New[Signer]) = invokelatest(Braider,unbox(deme),unbox(signer))


import PeaceVote.braid!


function braid!(config::BraiderConfig,notary::Notary,mixernotary::Notary,voter::Signer,signer::Signer)
    mixerid = config.mixerid[2]
    
    membergate = SocketConfig(config.gateid,DHsym(notary,signer),(socket,key)->SecureSocket(socket,key))
    membermixer = SocketConfig(mixerid,DHasym(mixernotary),(socket,key)->SecureSocket(socket,key))

    SynchronicBallot.vote(config.port,membergate,membermixer,voter.id,x->sign(x,signer))
end

#braid!(config::BraiderConfig,notary::New[Notary],mixernotary::New[Notary],voter::New[Signer],signer::New[Signer]) = invokelatest(braid!,config,unbox(notary),unbox(mixernotary),unbox(voter),unbox(signer))


### This is the method which one would need to type in manually so it would not call invokelatest before necessary. 
### Here one could use PeaceFounder to send stuff anonymously.
function braid!(config::BraiderConfig,notary::New[Notary],voter::New[Signer],signer::New[Signer])
    
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
#braid!(deme::New[ThisDeme],voter::New[Signer],signer::New[Signer]) = invokelatest(braid!,unbox(deme),unbox(voter),unbox(signer))


### The method for not needing to write boilerplate methods

### One defines the methods which accepts uninvoked arguments. Hopefully typed method with unions would superseede the untyped method.
