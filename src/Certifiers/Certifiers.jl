### Could be part of PeaceVote
module Certifiers

include("../debug.jl")

using ..Types: CertifierConfig, TookenID
using ..Crypto
using ..DataFormat: serialize, deserialize

using DiffieHellman: diffiehellman

using PeaceVote: Certificate, Signer, AbstractID, Deme, Notary
using Sockets


function validate!(tookens::Set,tooken)
    if tooken in tookens
        pop!(tookens,tooken)
        return true
    else
        return false
    end
end

### How to send back!

struct SecureRegistrator{T}
    server
    daemon
    messages::Channel{T}
end

function SecureRegistrator{T}(port,deme::Deme,validate::Function,signer::Signer) where T<:Any
    
    server = listen(port)
    messages = Channel{T}()
    
    dh = DHsym(deme,signer)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            key, id = diffiehellman(socket,dh)
            
            @assert validate(id)

            securesocket = deme.cypher.secureio(socket,key)
            message = deserialize(securesocket,T)
            put!(messages,message) 
        end
    end
    
    SecureRegistrator(server,daemon,messages)
end

struct TookenCertifier{T}
    server
    daemon
    tookens::Set{Int}
    tickets::Dict{Int,Certificate{T}}
end

function TookenCertifier{T}(port,deme::Deme,signer::Signer) where T<:AbstractID
    tookens = Set{Int}()   
    tickets = Dict{Int,Certificate{T}}()

    server = listen(port)
    dh = DHasym(deme,signer)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            key, id = diffiehellman(socket,dh)
            securesocket = deme.cypher.secureio(socket,key)

            id = deserialize(securesocket,TookenID{T}) ### Need to implement

            @assert id.tooken in tookens
            pop!(tookens,id.tooken)

            cert = Certificate(id.id,signer)

            tickets[id.tooken] = cert
            
            serialize(securesocket,cert) ### For this one we already jnow
        end
    end
    
    TookenCertifier(server,daemon,tookens,tickets)
end


struct Certifier{T<:AbstractID} 
    tookenrecorder::SecureRegistrator{Int}
    tookencertifier::TookenCertifier{T}
    daemon
end

function Certifier{T}(config::CertifierConfig,deme::Deme,signer::Signer) where T<:AbstractID
    
    tookenrecorder = SecureRegistrator{Int}(config.tookenport,deme,x->x in config.tookenca,signer)
    tookencertifier = TookenCertifier{T}(config.certifierport,deme,signer)

    daemon = @async while true
        tooken = take!(tookenrecorder.messages)
        push!(tookencertifier.tookens,tooken)
    end

    return Certifier(tookenrecorder,tookencertifier,daemon)
end


function addtooken(cc::CertifierConfig,deme::Deme,tooken::Int,signer::Signer)

    socket = connect(cc.tookenport)
    
    dh = DHsym(deme,signer)

    key, id = diffiehellman(socket,dh)

    @assert id in cc.serverid

    securesocket = deme.cypher.secureio(socket,key)

    serialize(securesocket,tooken)
end


function certify(cc::CertifierConfig,deme::Deme,id::T,tooken::Int) where T <: AbstractID

    socket = connect(cc.certifierport)

    dh = DHasym(deme)

    key, keyid = diffiehellman(socket,dh)

    @assert keyid in cc.serverid

    securesocket = deme.cypher.secureio(socket,key)
    serialize(securesocket,TookenID(id,tooken)) 
    
    cert = deserialize(securesocket,Certificate{T})

    return cert
end

export addtooken, Certifier, certify

end
