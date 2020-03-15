import Base.Dict

function Dict(record::AddressRecord)
    dict = Dict()
    if record.uuid!=nothing
        dict["uuid"] = string(record.uuid)
    end

    if record.hash!=nothing
        dict["hash"] = string(record.hash,base=16)
    end

    dict["id"] = string(record.id,base=16)
    dict["ip"] = string(record.ip)
    return dict
end

Dict(arecords::Vector{AddressRecord}) = Dict[Dict(i) for i in arecords]

function AddressRecord(config::Dict)
    if "uuid" in config.keys
        uuid = UUID(config["uuid"])
    else
        uuid = nothing
    end

    if "hash" in config.keys
        hash = parse(BigInt,config["hash"],base=16)
    else
        hash = nothing
    end

    id = parse(BigInt,config["id"],base=16)
    ip = IPv4(config["ip"])
    
    return AddressRecord(uuid,hash,id,ip)
end


function Dict(config::CertifierConfig)
    dict = Dict()
    dict["ca"] = string(config.tookenca,base=16)
    dict["server"] = string(config.serverid,base=16)
    dict["tport"] = config.tookenport.port
    dict["cport"] = config.certifierport.port
    return dict
end

function CertifierConfig(dict::Dict,arecords::Vector{AddressRecord})
    ca = parse(BigInt,dict["ca"],base=16)
    server = parse(BigInt,dict["server"],base=16)

    addr = ip(arecords,server)
    tport = Port(dict["tport"],addr)
    cport = Port(dict["cport"],addr)
    
    CertifierConfig(ca,server,tport,cport)
end


function Dict(config::BraiderConfig)
    dict = Dict()
    dict["N"] = config.N
    dict["server"] = string(config.gateid,base=16)
    dict["port"] = config.port.port
    mixer = Dict()
    mixer["uuid"] = string(config.mixerid[1])
    mixer["server"] = string(config.mixerid[2],base=16)
    mixer["port"] = config.ballotport.port
    dict["mixer"] = mixer
    return dict
end

function BraiderConfig(dict::Dict,arecords::Vector{AddressRecord})
    N = dict["N"]

    server = parse(BigInt,dict["server"],base=16)
    port = Port(dict["port"],ip(arecords,server))

    muuid = UUID(dict["mixer"]["uuid"])
    mserver = parse(BigInt,dict["mixer"]["server"],base=16)
    bport = Port(dict["mixer"]["port"],ip(arecords,mserver,muuid)) ### Braider needs to know the ip address of the mixer

    BraiderConfig(port,bport,N,server,(muuid,mserver))
end

function Dict(config::RecorderConfig)
    ca = Dict[]
    for mca in config.membersca
        dict = Dict()
        dict["uuid"] = string(mca[1])
        dict["id"] = string(mca[2],base=16)
        push!(ca,dict)
    end

    dict = Dict()
    dict["ca"] = ca
    dict["server"] = string(config.serverid,base=16)
    dict["rport"] = config.registratorport.port
    dict["vport"] = config.votingport.port
    dict["pport"] = config.proposalport.port
    
    return dict
end

function RecorderConfig(dict::Dict,arecords::Vector{AddressRecord})
    ca = [(UUID(i["uuid"]),parse(BigInt,i["id"],base=16)) for i in dict["ca"]]
    server = parse(BigInt,dict["server"],base=16)

    addr = ip(arecords,server)
    rport = Port(dict["rport"],addr)
    vport = Port(dict["vport"],addr)
    pport = Port(dict["pport"],addr)
    
    RecorderConfig(ca,server,rport,vport,pport)
end

function Dict(config::SystemConfig)
    dict = Dict()
    dict["mport"] = config.mixerport.port
    dict["sport"] = config.syncport.port
    dict["server"] = string(config.serverid,base=16)
    dict["certifier"] = Dict(config.certifier)
    dict["braider"] = Dict(config.braider)
    dict["recorder"] = Dict(config.recorder)

    return dict
end

function SystemConfig(dict::Dict)
    public = false ### It must be decided from arecords

    if haskey(dict,"arecords")
        arecords = AddressRecord[AddressRecord(i) for i in dict["arecords"]]
    else
        arecords = AddressRecord[]
    end

    server = parse(BigInt,dict["server"],base=16)
    addr = ip(arecords,server)
    mport = Port(dict["mport"],addr)
    sport = Port(dict["sport"],addr)

    certifier = CertifierConfig(dict["certifier"],arecords)
    braider = BraiderConfig(dict["braider"],arecords)
    recorder = RecorderConfig(dict["recorder"],arecords)

    SystemConfig(mport,sport,server,certifier,braider,recorder,arecords)
end

function Sealed{SystemConfig}(config::SystemConfig,maintainer::Signer)
    signature = maintainer.sign("$config")
    return Sealed(config,signature)
end

function Dict(config::Sealed{SystemConfig})
    sdict = Dict(config.signature)
    dict = Dict(config.data)
    dict["signature"] = sdict

    return dict
end

### I could have a function unseal to get the config I want
function Sealed{SystemConfig}(dict::Dict,notary::Notary)
    systemconfig = SystemConfig(dict)
    signature = notary.Signature(dict["signature"])
    return Sealed(systemconfig,signature)
end
