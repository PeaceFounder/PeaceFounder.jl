module MaintainerTools

using PeaceVote
using Base: UUID

using SMTPClient
using ..Types: SystemConfig, PFID
using ..Certifiers: Certifier
using ..Braiders: Mixer, Braider
using ..BraidChains: Recorder
using ..Ledgers: serve # I could name it as ledger node or something
using ..DataFormat

using PeaceVote: ticket

import ..Certifiers

using Sockets # do I need it?


### The configuration is stored in the ledger which can be transfered publically. One only needs to check that the configuration is signed by the server. So in the end one first downloads the ledger and then checks whether the configuration makes sense with serverid

### One should load system config with Deme. One thus would need to establish Ledger which thus would not require to have stuff. The constructor for Deme would be available here locally.

### Perhaps much better option would be to connect to the server over ssh since when one sets up the system one needs to have a key. We could use something like `scp` to copy a maintainerid and generate a server key executed by `julia "somefile.jl"` and returned that to a standart output. 

using Sockets

# One would write it in the setup file as
# SERVER_ID = configure("pi@192.1.1.1",MAINTAINER_ID)
# And then latter on decide what duties the SERVER_ID would have
function configure(ssh,maintainerid)
    # (1) Installs julia (uses curl for downloads)
    # (2) Sets up packages PeaceFounder and etc...
    # (3) adds MAINTAINER_ID as an environment variable
    # (4) starts configurator server
    # (5) returns SERVER_ID
end

### The configurration file is constructed locally
function deploy(port,serverid,signedconfig)
    socket = connect(port)

    signature = signer.sign(config)
    serilaize(socket,(config,signature))
    
    serversignature = deserialize(socket)
    config, id = unwrap((config,signature))
    @assert id in serverid
end

function init(port,maintainerid,signer::Signer)
    server = listen(port)
    socket = accept(server)
    
    # I should use read wiht opcodes
    cmd = deserialize(socket)
    
    while true
        
        if cmd==:configure

            config = deserialize(socket)
            file, id = unwrap(config)
            @assert id in maintainerid
            serialize(socket,signer.sign(config))

        elseif cmd==:reset
            # verification
            tooken = rand(1:100)
            serialize(socket,tooken)
            signature = deserialize(socket)
            tooken, id = unwrap((tooken,signature))
            @assert id in maintainerid
            # removing all configuration except the serverkey
        elseif cmd==:pass
            return nothing
        end
    end
end


### We will need some improvement here on 

function certify(deme::Deme,signer::Signer)
    @assert deme.spec.maintainer==signer.id "You are not eligible to certify PeaceFounder.toml for this deme"
    sc = deserialize(deme.ledger,SystemConfig)
    cert = Certificate(sc,signer)
    serialize(deme.ledger,cert)
end

### I might need to put this into Types. 
#Port(port) = Port(getipaddr(),port)

struct System
    deme::Deme
    mixer
    certifier
    braider
    braidchain
    synchronizer
end

# I could perhaps start the server from DemeSpec file. In that way I could generate appropriate deme. 


# This function starts the services which are specified fo this particular server. 
# When onion sockets will become a thing the System should also be started on the participating members
# devices or some additionall dedicated mixers.

function System(deme::Deme,server::Signer)

    config = deserialize(deme,SystemConfig)
    #config = SystemConfig(deme)
    
    if config.certifier==nothing
        certifier = nothing
    else
        certifier = Certifier{PFID}(config.certifier,deme,server)
    end
    
    mixer = Mixer(config.mixerport,deme,server)
    synchronizer = @async serve(config.syncport,deme.ledger)

    braider = Braider(config.braider,deme,server)

    ### So this is where the bug happens
    recorder = Recorder(config.recorder,deme,braider,server)

    return System(deme,mixer,certifier,braider,recorder,synchronizer)
end


addtooken(deme::Deme,tooken,signer::Signer) = Certifiers.addtooken(deserialize(deme,SystemConfig).certifier,deme,tooken,signer)


struct SMTPConfig
    url::AbstractString
    email::AbstractString
    password::Union{AbstractString,Nothing}
end

function SMTPConfig()
    println("Email:")
    email = readline()

    defaulturl = "smtps://smtp.gmail.com:465" 
    println("SMTP url [$defaulturl]:")
    url = readline()
    url=="" && (url = defaulturl)
    
    println("Password:")
    password = readline()
    
    SMTPConfig(url,email,password)

end


function sendinvite(config::SystemConfig,deme::Deme,to::AbstractString,from::SMTPConfig,maintainer::Signer)
    ### This would register a tooken with the system 

    tooken = rand(2^62:2^63-1)
    Certifiers.addtooken(config.certifier,deme,tooken,maintainer)

    port = config.syncport
    
    opt = SendOptions(isSSL = true, username = from.email, passwd = from.password)

    t = ticket(deme.spec,port,tooken)

    body = """
    From: $(from.email)
    To: $to
    Subject: Invitation to $(deme.spec.name)

    ########### Ticket #############
    $t
    ################################
    """
    
    send(from.url, [to], from.email, IOBuffer(body), opt)  
end


function sendinvite(deme::Deme,to::Vector{T},smtpconfig::SMTPConfig,maintainer::Signer) where T<:AbstractString
    config = deserialize(deme,SystemConfig)
    for ito in to
        sendinvite(config,deme,ito,smtpconfig,maintainer)
    end
end


sendinvite(deme::Deme,to::Vector{T},maintainer::Signer) where T<:AbstractString = sendinvite(deme,to,SMTPConfig(),maintainer)

export System

end
