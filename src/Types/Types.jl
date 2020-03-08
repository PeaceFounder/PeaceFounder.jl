module Types

### Every module needs to depend on Port. Thus it seems to be the right place.
struct Port
    ip
    port
end

import Sockets.listen
function listen(port::Port)
    port.ip==getipaddr() || @warn "Ip address of the Port does not match with the machine."
    listen(IPv4(0),port.port)
end

import Sockets.connect
connect(port::Port) = connect(port.ip,port.port)


struct CertifierConfig
    tookenca ### authorithies who can issue tookens. Server allows to add new tookens only from them.
    serverid ### Server receiveing tookens and the member identities. Is also the one which signs and issues the certificates.
    tookenport
    #hmac for keeping the tooken secret
    certifierport 
end

struct BraiderConfig
    port # braiderport
    ballotport # mixerport
    N
    gateid # braiderid
    mixerid
end

struct RecorderConfig
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
    recorder::RecorderConfig
end

export connect, listen

end
