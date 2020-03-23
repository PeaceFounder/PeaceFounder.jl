function stack(io::IO,msg::Vector{UInt8})
    frontbytes = reinterpret(UInt8,Int16[length(msg)])
    item = UInt8[frontbytes...,msg...]
    write(io,item)
end

function unstack(io::IO)
    sizebytes = [read(io,UInt8),read(io,UInt8)]
    size = reinterpret(Int16,sizebytes)[1]
    
    msg = UInt8[]
    for i in 1:size
        push!(msg,read(io,UInt8))
    end
    return msg
end


function serialize(io::IOBuffer,x::Contract{Braid}) 
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::IOBuffer,::Type{Contract{Braid}})
    str = String(take!(io))
    dict = TOML.parse(str)
    return Contract{Braid}(dict)
end



################# How could I parametrize it? ##############

import Base: GenericIOBuffer

### PFID

function serialize(io::GenericIOBuffer,x::Certificate{PFID}) 
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::GenericIOBuffer,::Type{Certificate{PFID}}) 
    str = String(take!(io))
    dict = TOML.parse(str)
    return Certificate{PFID}(dict)
end

function serialize(io::IO,x::Certificate{PFID})
    msg = IOBuffer()
    serialize(msg,x)
    stack(io,take!(msg))
end

function deserialize(io::IO,x::Type{Certificate{PFID}})
    msg = unstack(io)
    return deserialize(IOBuffer(msg),x)
end


### Proposal

function serialize(io::GenericIOBuffer,x::Certificate{Proposal}) 
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::GenericIOBuffer,::Type{Certificate{Proposal}}) 
    str = String(take!(io))
    dict = TOML.parse(str)
    return Certificate{Proposal}(dict)
end

function serialize(io::IO,x::Certificate{Proposal})
    msg = IOBuffer()
    serialize(msg,x)
    stack(io,take!(msg))
end

function deserialize(io::IO,x::Type{Certificate{Proposal}})
    msg = unstack(io)
    return deserialize(IOBuffer(msg),x)
end


### Vote

function serialize(io::GenericIOBuffer,x::Certificate{Vote}) 
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::GenericIOBuffer,::Type{Certificate{Vote}}) 
    str = String(take!(io))
    dict = TOML.parse(str)
    return Certificate{Vote}(dict)
end

function serialize(io::IO,x::Certificate{Vote})
    msg = IOBuffer()
    serialize(msg,x)
    stack(io,take!(msg))
end

function deserialize(io::IO,x::Type{Certificate{Vote}})
    msg = unstack(io)
    return deserialize(IOBuffer(msg),x)
end


##########################################


function serialize(deme::Deme,config::SystemConfig,signer::Signer)
    @assert deme.spec.maintainer==signer.id
    fname = configfname(deme.spec.uuid)
    mkpath(dirname(fname))
    
    sealedconfig = Certificate(config,signer)
    
    dict = Dict(sealedconfig)
    
    open(fname, "w") do io
        TOML.print(io, dict)
    end
end

### I could add function certify(deme::Deme,::Type{SystemConfig},maintainer::Signer) to load and add signature to the TOML file.


function deserialize(deme::Deme,::Type{SystemConfig})
    fname = configfname(deme.spec.uuid)
    @assert isfile(fname) "Config file not found!"

    dict = TOML.parsefile(fname)
    sc = Certificate{SystemConfig}(dict)

    intent = Intent(sc,deme.notary)
    #id = deme.notary.verify("$(sc.document)",sc.signature) 

    @assert intent.reference==deme.spec.maintainer
    return intent.document
end
