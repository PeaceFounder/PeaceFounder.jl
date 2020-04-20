module PeaceFounder

### Internal modules
#include("BraidChains/BraidChains.jl")

### The rest of the code

include("types.jl")
include("serialization.jl")
include("tools.jl")

import PeaceVote: record
record(config::PeaceFounderConfig,data) = record(config.braidchain,data)


import PeaceVote: sync!
sync!(chain::BraidChain,config::PeaceFounderConfig) = sync!(chain,config.braidchain.syncport)

using DemeNet: datadir

function updateconfig(deme::Deme)
    ddir = datadir(deme.spec.uuid)
    from = ddir * "/ledger/config/00000000"
    to = ddir * "/PeaceFounder.toml"    
    ### Before copying one can verify that the config had been signed by the maintainer
    cp(from,to,force=true)
end

function init(deme::Deme,port::Port)
    ledger = Ledger(deme.spec.uuid)
    sync!(ledger,port)
    cp(chain.ledger * "/config/00000000",fname,force=true)
end

init(deme::Deme,port::Dict) = init(deme,Port(port))

function config(deme::Deme)
    cert = deserialize(deme,Certificate{PeaceFounderConfig})
    intent = Intent(cert,deme.notary)
    @assert intent.reference==deme.spec.maintainer
    return intent.document
end

import PeaceVote: BraidChain
BraidChain(config::PeaceFounderConfig,deme::Deme) = BraidChain(config.braidchain,deme)
BraidChain(deme::Deme) = BraidChain(config(deme),deme)


# function certify(chain::BraidChain,signer::Signer)
#     @assert chain.deme.spec.maintainer==signer.id "You are not eligible to certify PeaceFounder.toml for this deme"
#     sc = deserialize(chain.deme,PeaceFounderConfig)
#     cert = Certificate(sc,signer)
#     writebootrecord(chain.ledger,cert)
#     updateconfig(chain.deme)
# end


function certify(deme::Deme,signer::Signer)
    @assert deme.spec.maintainer==signer.id "You are not eligible to certify PeaceFounder.toml for this deme"
    sc = deserialize(deme,PeaceFounderConfig)
    cert = Certificate(sc,signer)

    writebootrecord(deme,cert)
    updateconfig(deme)
end


end # module
