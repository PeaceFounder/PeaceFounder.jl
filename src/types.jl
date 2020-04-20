using DemeNet: ID, DemeID
using Base: UUID, Dict
using Sockets

import Base.Dict
import PeaceVote: BraiderConfig, RecorderConfig, BraidChainConfig
import Recruiters: CertifierConfig


struct Port
    port::Int
    ip::Union{Nothing,IPv4,IPv6} 
end

Port(port::Int) = Port(port,nothing)

function Dict(port::Port)
    dict = Dict{String,Union{String,Int}}("port"=>port.port)
    if !isnothing(port.ip) 
        dict["ip"] = string(port.ip)
        dict["type"] = "$(typeof(port.ip))"
    else
        dict["type"] = "Int"
    end

    return dict
end

function Port(dict::Dict)
    port = dict["port"]
    type = dict["type"]
    if type == "Int"
        ip = nothing
    elseif type == "IPv4"
        ip = IPv4(dict["ip"])
    elseif type == "IPv6"
        ip = IPv6(dict["ip"])
    end
    return Port(port,ip)
end


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

function Dict(record::AddressRecord)
    dict = Dict()

    if typeof(record.id)==DemeID
        dict["uuid"] = string(record.id.uuid)
    end

    if record.hash!=nothing
        dict["hash"] = string(record.hash,base=16)
    end

    dict["id"] = string(record.id.id,base=16)
    dict["ip"] = string(record.ip)
    return dict
end

Dict(arecords::Vector{AddressRecord}) = Dict[Dict(i) for i in arecords]

function AddressRecord(config::Dict)
    localid = parse(BigInt,config["id"],base=16)

    if "uuid" in config.keys
        uuid = UUID(config["uuid"])
        id = DemeID(uuid,localid)
    else
        id = ID(localid)
    end

    if "hash" in config.keys
        hash = parse(BigInt,config["hash"],base=16)
    else
        hash = nothing
    end

    ip = IPv4(config["ip"])
    
    return AddressRecord(id,hash,ip)
end


function Dict(config::CertifierConfig{Port})
    dict = Dict()
    dict["ca"] = string(config.tookenca.id,base=16)
    dict["server"] = string(config.serverid.id,base=16)
    dict["tport"] = config.tookenport.port
    dict["cport"] = config.certifierport.port
    return dict
end

function CertifierConfig{Port}(dict::Dict,arecords::Vector{AddressRecord})
    ca = ID(parse(BigInt,dict["ca"],base=16))
    server = ID(parse(BigInt,dict["server"],base=16))

    addr = ip(arecords,server)
    tport = Port(dict["tport"],addr)
    cport = Port(dict["cport"],addr)
    
    CertifierConfig(ca,server,tport,cport)
end


function Dict(config::BraiderConfig{Port})
    dict = Dict()
    dict["N"] = Int(config.N)
    dict["M"] = Int(config.M)
    dict["server"] = string(config.gateid.id,base=16)
    dict["port"] = config.port.port
    mixer = Dict()
    mixer["uuid"] = string(config.mixerid.uuid)
    mixer["server"] = string(config.mixerid.id,base=16)
    mixer["port"] = config.ballotport.port
    dict["mixer"] = mixer
    return dict
end

function BraiderConfig{Port}(dict::Dict,arecords::Vector{AddressRecord})
    N = UInt8(dict["N"])
    M = UInt8(dict["M"])

    server = ID(parse(BigInt,dict["server"],base=16))
    port = Port(dict["port"],ip(arecords,server))

    muuid = UUID(dict["mixer"]["uuid"])
    mserver = parse(BigInt,dict["mixer"]["server"],base=16)

    mid = DemeID(muuid,mserver)
    bport = Port(dict["mixer"]["port"],ip(arecords,mid)) ### Braider needs to know the ip address of the mixer

    BraiderConfig(port,bport,N,M,server,mid)
end

function Dict(config::RecorderConfig{Port})
    ca = Dict[]
    for mca in config.membersca
        dict = Dict()
        dict["id"] = string(mca.id,base=16)
        if typeof(mca)==DemeID
            dict["uuid"] = string(mca.uuid)
        end
        push!(ca,dict)
    end

    dict = Dict()
    dict["ca"] = ca
    dict["server"] = string(config.serverid.id,base=16)
    dict["rport"] = config.registratorport.port
    dict["vport"] = config.votingport.port
    dict["pport"] = config.proposalport.port
    
    return dict
end

function RecorderConfig{Port}(dict::Dict,arecords::Vector{AddressRecord})
    
    ca = Union{ID,DemeID}[]
    for i in dict["ca"]
        localid = parse(BigInt,i["id"],base=16)
        if haskey(i,"uuid")
            uuid = UUID(i["uuid"])
            push!(ca,DemeID(uuid,localid))
        else
            push!(ca,ID(localid))
        end
    end

    server = ID(parse(BigInt,dict["server"],base=16))

    addr = ip(arecords,server)
    rport = Port(dict["rport"],addr)
    vport = Port(dict["vport"],addr)
    pport = Port(dict["pport"],addr)
    
    RecorderConfig(ca,server,rport,vport,pport)
end

function Dict(config::BraidChainConfig{Port})

    dict = Dict()
    dict["server"] = string(config.server,base=16)
    dict["mport"] = config.mixerport.port
    dict["sport"] = config.syncport.port
    dict["braider"] = Dict(config.braider)
    dict["recorder"] = Dict(config.recorder)
    
    return dict
end

function BraidChainConfig{Port}(dict::Dict,arecords::Vector{AddressRecord})

    server = ID(parse(BigInt,dict["server"],base=16))
    addr = ip(arecords,server)
    mport = Port(dict["mport"],addr)
    sport = Port(dict["sport"],addr)

    braider = BraiderConfig{Port}(dict["braider"],arecords)
    recorder = RecorderConfig{Port}(dict["recorder"],arecords)

    BraidChainConfig(server,mport,sport,braider,recorder)
end

struct PeaceFounderConfig
    braidchain::BraidChainConfig{Port}
    certifier::CertifierConfig{Port} 
    arecords::Vector{AddressRecord}    
end

function Dict(config::PeaceFounderConfig)
    dict = Dict("braidchain"=>Dict(config.braidchain),"certifier"=>Dict(config.certifier))
    length(config.arecords)>0 && (dict["arecords"]=Dict(config.arecords))
    return dict
end

function PeaceFounderConfig(dict::Dict)
    
    if haskey(dict,"arecords")
        arecords = AddressRecord[AddressRecord(i) for i in dict["arecords"]]
    else
        arecords = AddressRecord[]
    end

    certifier = CertifierConfig{Port}(dict["certifier"],arecords)
    braidchain = BraidChainConfig{Port}(dict["braidchain"],arecords)


    return PeaceFounderConfig(braidchain,certifier,arecords)
end


