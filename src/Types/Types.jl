module Types

using PeaceVote: Certificate, Contract, Intent, Consensus, AbstractVote, AbstractProposal, AbstractID, AbstractBraid, ID, DemeID
using Sockets
using Base: UUID
import Base.Dict

### ToDo

# Put the dictionary stuff in the DataFormat.jl submodule as intended. 


### Every module needs to depend on Port. Thus it seems to be the right place.
struct Port
    port::Int
    ip::Union{Nothing,IPv4,IPv6} 
end

Port(port::Int) = Port(port,nothing)

import Sockets.listen
function listen(port::Port)
    if port.ip isa Nothing
        listen(port.port)
    elseif port.ip isa IPv4
        listen(IPv4(0),port.port)
    else
        listen(IPv6(0),port.port)
    end
end

import Sockets.connect
function connect(port::Port)
    if port.ip isa Nothing
        connect(port.port)
    else
        connect(port.ip,port.port)
    end
end

# I could add also a hash of demefile here!
struct AddressRecord
    id::Union{ID,DemeID}
    hash::Union{Nothing,BigInt}
    ip::Union{IPv4,IPv6}
end

function ip(machines::Vector{AddressRecord},id::Union{ID,DemeID})
    for m in machines
        if m.id==id
            return m.ip
        end
    end
end

#ip(machines::Vector{AddressRecord},id::BigInt) = ip(machines,id,nothing)


# On the other hand connect is used by user methods. I could thus achieve that in a simple manner. For the port one just need to 

# ipaddr = ip(machines,id) or ip(machines,id,uuid)

### Let's make stuff first for SystemConfig. 

struct CertifierConfig
    tookenca::ID ### authorithies who can issue tookens. Server allows to add new tookens only from them.
    serverid::ID ### Server receiveing tookens and the member identities. Is also the one which signs and issues the certificates.
    tookenport::Port
    #hmac for keeping the tooken secret
    certifierport::Port
end


### Perhaps I could introduce a Mixer subtype.
struct BraiderConfig
    port::Port # braiderport
    ballotport::Port # mixerport
    N::Int
    gateid::ID # braiderid
    mixerid::DemeID
end


struct RecorderConfig
#    maintainerid::BigInt # The one which signs the config file
    membersca::Vector{Union{DemeID,ID}} ### One needs to explicitly add the certifier server id here. That's because 
    serverid::ID
    registratorport::Port ### The port to which the certificate of membership is delivered
    votingport::Port
    proposalport::Port
end

   
struct SystemConfig
    mixerport::Port
    syncport::Port
    serverid::ID
    certifier::Union{CertifierConfig,Nothing}
    braider::BraiderConfig
    recorder::RecorderConfig
    arecords::Vector{AddressRecord}
end

### 
struct Vote <: AbstractVote
    pid::Int ### One gets it from a BraidChain loking into a sealed proposal
    vote::Int ### Number or a message
end

struct Proposal <: AbstractProposal
    msg::AbstractString
    options::Vector{T} where T<:AbstractString
end

import Base.==
==(a::Proposal,b::Proposal) = a.msg==b.msg && a.options==b.options

### The main task of this type is to have enough information to 
### establish the trust.
struct PFID <: AbstractID
    name::AbstractString
    date::AbstractString
    id::ID
end

struct Braid <: AbstractBraid
    index::Union{Nothing,Int} ### latest index of the ledger
    hash::Union{Nothing,BigInt} ### hash of the ledger up to the latest index
    ids # Vector{ID} ### the new ids for the public keys
end

# struct Sealed{T}
#     data::T
#     signature
# end

### At this point I may be able to define how the files should look like

export connect, listen, Port

end
