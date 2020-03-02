module MaintainerTools

using PeaceVote

using Synchronizers: Ledger

using ..Braiders: BraiderConfig
using ..Certifiers: CertifierConfig
using ..BraidChains: BraidChainConfig

const ThisDeme = Deme

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


include("configure.jl")
include("systemserver.jl")


end
