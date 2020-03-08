### Could be part of PeaceVote
module Certifiers

using ..Types: CertifierConfig
using PeaceVote: Certificate, Signer, AbstractID, ID, Deme, Notary
using Sockets
using DiffieHellman
using Serialization


const ThisDeme = Deme

struct TookenID <: AbstractID
    id::ID
    tooken
end

unwrap(envelope::TookenID) = (envelope.id,envelope.tooken)

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

function SecureRegistrator(port,notary::Notary,validate::Function,signer::Signer)
    
    
    server = listen(port)
    messages = Channel()
    
    dh = DH(signer,notary)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            send = x-> serialize(socket,x)
            get = () -> deserialize(socket)
            
            key, id = diffiehellman(send,get,dh)
            
            @assert validate(id)

            securesocket = SecureSocket(socket,key)
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
end

function TookenCertifier(port,notary::Notary,signer::Signer)
    tookens = Set()   

    server = listen(port)
    #server = listen(config.certifierport)
    #dh = DH(wrap(signer),x->(x,nothing),G,chash,()->rngint(100))
    dh = DH(signer)

    daemon = @async while true
        socket = accept(server)
        @async begin
            
            send = x-> serialize(socket,x)
            get = () -> deserialize(socket)
            key, id = diffiehellman(send,get,dh)
            securesocket = SecureSocket(socket,key)

            id = deserialize(securesocket)

            @assert id.tooken in tookens
            pop!(tookens,id.tooken)

            cert = Certificate(id,signer)
            
            serialize(securesocket,cert)
        end
    end
    
    TookenCertifier(server,daemon,tookens)
end


struct Certifier
    tookenrecorder
    tookencertifier
    daemon
end

function Certifier(deme::ThisDeme,signer::Signer)
    
    systemconfig = SystemConfig(deme)
    config = systemconfig.certifier
    
    tookenrecorder = SecureRegistrator(config.tookenport,deme.notary,x->x in config.tookenca,signer)
    tookencertifier = TookenCertifier(config.certifierport,deme.notary,signer)

    daemon = @async while true
        tooken = take!(tookenrecorder.messages)
        push!(tookencertifier.tookens,tooken)
    end

    Certifier(tookenrecorder,tookencertifier,daemon)
end


function addtooken(deme::ThisDeme,tooken,signer::Signer)

    systemconfig = SystemConfig(deme)
    cc = systemconfig.certifier

    socket = connect(cc.tookenport)
    
    dh = DH(signer,deme.notary)

    send = x-> serialize(socket,x)
    get = () -> @show deserialize(socket)

    @show key, id = diffiehellman(send,get,dh)

    @assert id in cc.serverid

    securesocket = SecureSocket(socket,key)
    serialize(securesocket,tooken)
end


function certify(deme::ThisDeme,tookenid::TookenID)

    systemconfig = SystemConfig(deme)
    cc = systemconfig.certifier

    socket = connect(cc.certifierport)

    dh = DH(deme.notary)

    send = x-> serialize(socket,x)
    get = () -> @show deserialize(socket)

    @show key, id = diffiehellman(send,get,dh)

    @assert id in cc.serverid

    securesocket = SecureSocket(socket,key)
    serialize(securesocket,tookenid)
    
    cert = deserialize(securesocket)

    return cert
end

certify(deme::ThisDeme,id::ID,tooken) = certify(deme,TookenID(id,tooken))

end
