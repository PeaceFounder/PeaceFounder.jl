module Braiders

using ..Crypto

import SynchronicBallot
using SynchronicBallot: SocketConfig
using PeaceVote: DemeSpec, Notary, Cypher, Signer, Deme, Contract, Certificate, ID, DemeID

using ..Types: BraiderConfig, Braid

using Pkg.TOML

import ..Types: Braid

function Braid(metadata::Vector{UInt8},ballot::Array{UInt8,2})

    ids = ID[]

    N = size(ballot,2)

    for i in 1:N
        id = ID(ballot[:,i],base=16)
        push!(ids,id)
    end
    
    braid = Braid(nothing,nothing,ids)

    return braid
end

function validate(braid::Braid,id::ID,deme::Deme)
    return id in braid.ids
end

function signbraid(metadata::Vector{UInt8},ballot::Array{UInt8,2},validate::Function,signer::Signer)

    braid = Braid(metadata,ballot)

    @assert validate(braid)

    cert = Certificate(braid,signer)
    
    sdict = Dict(cert.signature)
    io = IOBuffer()
    TOML.print(io,sdict)
    return take!(io)
end

const ThisDeme = Deme

function Mixer(port,cypher::Cypher,notary::Notary,signer::Signer)
    mixergate = SocketConfig(nothing,DHasym(cypher,notary,signer),cypher.secureio)
    mixermember = SocketConfig(nothing,DHasym(cypher,notary,signer),cypher.secureio)

    return SynchronicBallot.Mixer(port,mixergate,mixermember) # should be renamed to Mixer
end

Mixer(port,deme::ThisDeme,signer::Signer) = Mixer(port,deme.cypher,deme.notary,signer)

struct Braider
    server
    voters::Set{ID}
end

import Base.take!

### Perhaps I also need to put metadata with the ballots channel. 
### Because otherwise we may loose a track (a simple bugfix)
function take!(braider::Braider) 
    metadata,ballot,signaturesbin = take!(braider.server.ballots)
    braid = Braid(UInt8[],ballot)
    signatures = Dict{String,Any}[TOML.parse(String(i)) for i in signaturesbin]
    contract = Contract(braid,signatures)
    return contract
end

function Braider(braider::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,signer::Signer) 

    voters = Set{ID}()

    gatemixer = SocketConfig(braider.mixerid.id,DHasym(mixerdeme.cypher,mixerdeme.notary),mixerdeme.cypher.secureio)
    gatemember =  SocketConfig(voters,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)

    server = SynchronicBallot.GateKeeper(braider.port,braider.ballotport,braider.N,braider.M,gatemixer,gatemember,()->UInt8[]) #() -> Vector{UInt8}(""))
    Braider(server,voters)
end

# New in this context just overloads generated function since it is not necessary.
function Braider(braider::BraiderConfig,deme::ThisDeme,signer::Signer)
    mixeruuid = braider.mixerid.uuid

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,ledger=false)
    
    Braider(braider,deme,mixerdeme,signer)
end


function Braider(deme::ThisDeme,signer::Signer)
    systemconfig = SystemConfig(deme) ### This is where the config file is verified
    braider = systemconfig.braider
    Braider(braider,deme,signer)
end

import PeaceVote.braid!

function braid!(config::BraiderConfig,deme::ThisDeme,mixerdeme::Deme,voter::Signer,signer::Signer)
    
    membergate = SocketConfig(config.gateid,DHsym(deme.cypher,deme.notary,signer),deme.cypher.secureio)
    membermixer = SocketConfig(config.mixerid.id,DHasym(mixerdeme.cypher,mixerdeme.notary),deme.cypher.secureio)

    ### I need to take out a validate function, to check the braid formed by the server 
    # (2) The hash of the full ledger
    # (3) Some other metadata. Whether the same port was used by everyone to form the braid as well the same mixer and server. 

    idbytes = Vector{UInt8}(voter.id,base=16,length=config.M)

    SynchronicBallot.vote(config.port,membergate,membermixer,idbytes,(m,b)->signbraid(m,b,braid->validate(braid,voter.id,deme),signer))
end

function braid!(config::BraiderConfig,deme::ThisDeme,voter::Signer,signer::Signer)
    mixeruuid = config.mixerid.uuid

    mixerdemespec = DemeSpec(mixeruuid)
    mixerdeme = Deme(mixerdemespec,ledger=false) 

    braid!(config,deme,mixerdeme,voter,signer)
end

function braid!(deme::ThisDeme,voter::Signer,signer::Signer)
    systemconfig = SystemConfig(deme)
    config = systemconfig.braider
    braid!(config,deme,voter,signer)
end

export Mixer, Braider, braid!

end # module


