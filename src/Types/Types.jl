module Types

using DemeNet: Certificate, Contract, Intent, Consensus, AbstractID, ID, DemeID, Deme
using PeaceVote.Plugins: AbstractVote, AbstractProposal, AbstractBraid, AbstractChain
using Sockets
using Base: UUID

using Recruiters: CertifierConfig
#import PeaceVote: load 

import Base.Dict

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

### Let's make stuff first for SystemConfig. 



### Perhaps I could introduce a Mixer subtype.
struct BraiderConfig
    port::Port # braiderport
    ballotport::Port # mixerport
    N::UInt8
    M::UInt8
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
    ids::Vector{ID} ### the new ids for the public keys
end


struct BraidChain <: AbstractChain
    deme::Deme
    ledger
end


include("systemconfig.jl")
include("chaintypes.jl")

### At this point I may be able to define how the files should look like

export connect, listen, Port

end
