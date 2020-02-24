# Methods for analyzing the braidchain
using Sockets
using Synchronizers: Ledger
import Synchronizers
using Serialization

struct Port
    ip
    port
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
    mixer
    certifier
    braider
    braidchain
    synchronizer
    ledger
end

# This function starts the services which are specified fo this particular server. 
# When onion sockets will become a thing the System should also be started on the participating members
# devices or some additionall dedicated mixers.
function System(deme::ThisDeme,server::Signer)
    config = SystemConfig(deme)

    mixer = Mixer(config.mixerport,server)
    certifier = Certifier(config.certifier,server)

    ledger = Ledger(datadir() * "/$deme/")
    synchronizer = @async Synchronizers.serve(config.syncport,ledger)

    braider = Braider(config.braider,server)
    
    braidchain = BraidChainServer(ledger,config.bcconfig,braider,server)

    return System(mixer,certifier,braider,braidchain,synchronizer,ledger)
end

#serve(server::Signer) = serve(datadir(),SystemConfig(),server)
