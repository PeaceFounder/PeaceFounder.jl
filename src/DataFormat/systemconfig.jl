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


function Dict(config::CertifierConfig)
    dict = Dict()
    dict["ca"] = string(config.tookenca.id,base=16)
    dict["server"] = string(config.serverid.id,base=16)
    dict["tport"] = config.tookenport.port
    dict["cport"] = config.certifierport.port
    return dict
end

function CertifierConfig(dict::Dict,arecords::Vector{AddressRecord})
    ca = ID(parse(BigInt,dict["ca"],base=16))
    server = ID(parse(BigInt,dict["server"],base=16))

    addr = ip(arecords,server)
    tport = Port(dict["tport"],addr)
    cport = Port(dict["cport"],addr)
    
    CertifierConfig(ca,server,tport,cport)
end


function Dict(config::BraiderConfig)
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

function BraiderConfig(dict::Dict,arecords::Vector{AddressRecord})
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

function Dict(config::RecorderConfig)
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

function RecorderConfig(dict::Dict,arecords::Vector{AddressRecord})
    
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

function Dict(config::SystemConfig)
    dict = Dict()
    dict["mport"] = config.mixerport.port
    dict["sport"] = config.syncport.port
    dict["server"] = string(config.serverid.id,base=16)
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

    server = ID(parse(BigInt,dict["server"],base=16))
    addr = ip(arecords,server)
    mport = Port(dict["mport"],addr)
    sport = Port(dict["sport"],addr)

    certifier = CertifierConfig(dict["certifier"],arecords)
    braider = BraiderConfig(dict["braider"],arecords)
    recorder = RecorderConfig(dict["recorder"],arecords)

    SystemConfig(mport,sport,server,certifier,braider,recorder,arecords)
end

function Dict(port::Port)
    dict = Dict("port"=>port.port)
    isnothing(port.ip) || (dict["ip"]=string(port.ip))
    return dict
end

function Port(dict::Dict)
    port = dict["port"]
    haskey(dict,"ip") ? (ip=IPv4(dict["ip"])) : ip=nothing
    return Port(port,ip)
end

