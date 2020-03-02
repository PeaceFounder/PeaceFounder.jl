### We will need some improvement here on 
using Sockets
import Synchronizers
using Serialization

import Base.UUID

struct Port
    ip
    port
end

### But perhaps before that I could relly simply on Synchronizers which did work previously 
struct ThisLedger
    port
    ledger
end

import PeaceVote.Ledger
function Ledger(::Type{ThisDeme},uuid::UUID,port)
    ledger = Synchronizers.Ledger(PeaceVote.datadir(uuid))
    return ThisLedger(port,ledger)
end


#Port(port) = Port(getipaddr(),port)

import Sockets.listen
function listen(port::Port)
    port.ip==getipaddr() || @warn "Ip address of the Port does not match with the machine."
    listen(IPv4(0),port.port)
end

import Sockets.connect
connect(port::Port) = connect(port.ip,port.port)


struct System
    deme::ThisDeme
    mixer
    certifier
    braider
    braidchain
    synchronizer
end

# I could perhaps start the server from DemeSpec file. In that way I could generate appropriate deme. 


# This function starts the services which are specified fo this particular server. 
# When onion sockets will become a thing the System should also be started on the participating members
# devices or some additionall dedicated mixers.


function System(deme::Deme,server::Signer)

    config = SystemConfig(deme)
    
    mixer = Mixer(config.mixerport,deme,server)
    certifier = nothing # Certifier(config.certifier,server)
    synchronizer = @async Synchronizers.serve(config.syncport,deme.ledger)

    braider = Braider(config.braider,deme,server)

    ### SO this is where the bug happens
    braidchain = BraidChainServer(deme,braider,server)

    return System(deme,mixer,certifier,braider,braidchain,synchronizer)
end

### With an abstraction it is also possible to instantiate a Ledger. This ledger type would benefit from incremental updates to the cached braidchain.

function System(spec::DemeSpec,server::Signer)

    notary = Notary(spec)
    cypher = Cypher(spec)
    ledger = Synchronizers.Ledger(PeaceVote.datadir(spec.uuid))
    deme = Deme(spec,notary,cypher,ledger)

    return System(deme,server)
end

#serve(server::Signer) = serve(datadir(),SystemConfig(),server)
