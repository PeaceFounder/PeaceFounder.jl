module PeaceFounder

# ToDo
# - Add a maintainer port which would receive tookens. 
# - Couple thoose tookens with registration. So only a memeber with it can register. Make the server to issue the certificates on the members.
# - Write the server.jl file. Make it automatically generate the server key.
# - The server id will also be the uuid of the community subfolder. Need to extend PeaceVote so it woul support such generics. (keychain already has accounts. Seems only ledger would be necessary to be supported with id.)
# - A configuration file must be created during registration. So one could execute braid! and vote commands with keychain. That also means we need an account keyword for the keychain.
# - Test that the user can register if IP addreess, SERVER_ID and tooken is provided.


### Perhaps I could have a package CommunityUtils
using Synchronizers: Synchronizer, Ledger, sync

using PeaceVote
import PeaceVote.save
using PeaceVote: datadir

import PeaceVote: register, braid!, vote, propose


const ThisDeme = PeaceVote.DemeType(@__MODULE__)


### To make writing invokelatest easier

import Base.invokelatest

# const NewNotary = Union{Notary,New{Notary}}
# const NewSigner = Union{Signer,New{Signer}}
# const NewThisDeme = Union{ThisDeme,New{ThisDeme}}



#datadir(deme::ThisDeme) = PeaceVote.datadir(deme)


#const CONFIG = dirname(dirname(@__FILE__)) * "/Config"

#datadir() = PeaceVote.datadir(PeaceVote.uuid("DemeAssemblies"))

#const CONFIG = dirname(dirname(@__FILE__)) * "/Config"


struct BraiderConfig
    port # braiderport
    ballotport # mixerport
    N
    gateid # braiderid
    mixerid
end

struct CertifierConfig
    tookenca ### authorithies who can issue tookens. Server allows to add new tookens only from them.
    serverid ### Server receiveing tookens and the member identities. Is also the one which signs and issues the certificates.
    tookenport
    #hmac for keeping the tooken secret
    certifierport 
end

struct BraidChainConfig
    maintainerid # The one which signs the config file
    membersca ### One needs to explicitly add the certifier server id here. That's because 
    serverid
    registratorport ### The port to which the certificate of membership is delivered
    votingport
    proposalport
end


struct SystemConfig
    mixerport
    syncport
    certifier::Union{CertifierConfig,Nothing}
    braider::BraiderConfig
    braidchain::BraidChainConfig
end

### The configuration is stored in the ledger which can be transfered publically. One only needs to check that the configuration is signed by the server. So in the end one first downloads the ledger and then checks whether the configuration makes sense with serverid

### One should load system config with Deme. One thus would need to establish Ledger which thus would not require to have stuff. The constructor for Deme would be available here locally.

function SystemConfig(spec::DemeSpec,notary::Notary)
    fname = datadir(spec.uuid) * "/CONFIG"
    @assert isfile(fname) "Config file not found!"
    config, signature = Serialization.deserialize(fname)
    id = verify(config,signature,notary) 
    @assert id==spec.maintainer
    return config
end

SystemConfig(deme::DemeSpec) = SystemConfig(deme.spec,Notary(deme))
SystemConfig(deme::ThisDeme) = SystemConfig(deme.spec,deme.notary)


function save(config::SystemConfig,signer::Signer)
    uuid = signer.uuid
    fname = datadir(uuid) * "/CONFIG"
    mkpath(dirname(fname))
    signature = sign(config,signer)
    Serialization.serialize(fname,(config,signature))
end

BraidChainConfig(serverid) = SystemConfig(serverid).braidchain

import Synchronizers.Ledger
Ledger(serverid::BigInt) = Ledger(datadir() * "/$serverid/")

sync!(ledger::Ledger,syncport) = sync(Synchronizer(syncport,ledger))

function sync!(ledger::Ledger)
    serverid = parse(BigInt,basename(dirname(ledger.dir)))
    config = SystemConfig(serverid)
    sync!(ledger,config.syncport)
end

function SystemConfig(syncport,serverid)
    ledger = Ledger(serverid)
    sync!(ledger,syncport)
    return SystemConfig(serverid)
end


include("debug.jl")

include("crypto.jl")
include("analysis.jl") 
include("configure.jl")
include("certifier.jl") 
include("braider.jl")
include("braidchainserver.jl")
include("systemserver.jl")


export register, braid!, propose, vote, braidchain, members, count, sync!, Ledger

end # module
