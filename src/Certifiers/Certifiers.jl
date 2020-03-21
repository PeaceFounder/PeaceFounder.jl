### Could be part of PeaceVote
module Certifiers

include("../debug.jl")

using ..Types: CertifierConfig
using ..Crypto
using DiffieHellman: diffiehellman

using PeaceVote: Certificate, Signer, AbstractID, Deme, Notary
using Sockets
using Serialization


function validate!(tookens::Set,tooken)
    if tooken in tookens
        pop!(tookens,tooken)
        return true
    else
        return false
    end
end

### How to send back!

struct SecureRegistrator
    server
    daemon
    messages # a Channel
end

function SecureRegistrator(port,deme::Deme,validate::Function,signer::Signer)
    
    server = listen(port)
    messages = Channel()
    
    dh = DHsym(deme,signer)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            send = x-> serialize(socket,x)
            get = () -> deserialize(socket)
            
            key, id = diffiehellman(send,get,dh)
            
            @assert validate(id)

            securesocket = deme.cypher.secureio(socket,key)
            message = deserialize(securesocket)
            put!(messages,message) 
        end
    end
    
    SecureRegistrator(server,daemon,messages)
end

struct TookenCertifier
    server
    daemon
    tookens
    tickets
end

function TookenCertifier(port,deme::Deme,signer::Signer)
    tookens = Set()   
    tickets = Dict()

    server = listen(port)
    dh = DHasym(deme,signer)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            send = x-> serialize(socket,x)
            get = () -> deserialize(socket)
            key, id = diffiehellman(send,get,dh)
            securesocket = deme.cypher.secureio(socket,key)

            tooken,id = deserialize(securesocket)

            @assert tooken in tookens
            pop!(tookens,tooken)

            cert = Certificate(id,signer)

            tickets[tooken] = cert
            
            serialize(securesocket,cert)
        end
    end
    
    TookenCertifier(server,daemon,tookens,tickets)
end


struct Certifier
    tookenrecorder
    tookencertifier
    daemon
end

function Certifier(config::CertifierConfig,deme::Deme,signer::Signer)
    
    tookenrecorder = SecureRegistrator(config.tookenport,deme,x->x in config.tookenca,signer)
    tookencertifier = TookenCertifier(config.certifierport,deme,signer)

    daemon = @async while true
        tooken = take!(tookenrecorder.messages)
        push!(tookencertifier.tookens,tooken)
    end

    return Certifier(tookenrecorder,tookencertifier,daemon)
end


function addtooken(cc::CertifierConfig,deme::Deme,tooken,signer::Signer)

    socket = connect(cc.tookenport)
    
    dh = DHsym(deme,signer)

    send = x-> serialize(socket,x)
    get = () -> deserialize(socket)

    key, id = diffiehellman(send,get,dh)

    @assert id in cc.serverid

    securesocket = deme.cypher.secureio(socket,key)
    serialize(securesocket,tooken)
end


function certify(cc::CertifierConfig,deme::Deme,id::AbstractID,tooken)

    socket = connect(cc.certifierport)

    dh = DHasym(deme)

    send = x-> serialize(socket,x)
    get = () -> deserialize(socket)

    key, keyid = diffiehellman(send,get,dh)

    @assert keyid in cc.serverid

    securesocket = deme.cypher.secureio(socket,key)
    serialize(securesocket,(tooken,id))
    
    cert = deserialize(securesocket)

    return cert
end

export addtooken, Certifier, certify

end
