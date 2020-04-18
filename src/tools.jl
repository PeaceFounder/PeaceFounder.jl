
using DemeNet: Signer, Deme, ID, DemeID, Certificate, serialize, deserialize, datadir, Profile, Intent
using Base: UUID

#using ..Types: SystemConfig, PFID, BraidChain
#using ..Braiders: Mixer, Braider
using .BraidChains: BraidChain, BraidChainServer, record
#Recorder, register
#using ..Ledgers: serve # I could name it as ledger node or something
#using ..DataFormat

using Recruiters: Certifier
import Recruiters
import Recruiters: ticket, addtooken
#using PeaceVote.KeyChains: ticket ### Will be part of Recruiters.jl

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


### I might need to put this into Types. 
#Port(port) = Port(getipaddr(),port)

struct PeaceFounderServer
    chain::BraidChain
    braidchain
    certifier
end

# I could perhaps start the server from DemeSpec file. In that way I could generate appropriate deme. 


# This function starts the services which are specified fo this particular server. 
# When onion sockets will become a thing the System should also be started on the participating members
# devices or some additionall dedicated mixers.

function storeprofile(cert::Certificate{Profile},deme::Deme)
    uuid = deme.spec.uuid
    intentprofile = Intent(cert,deme.notary)
    id = intentprofile.reference

    fname = datadir(uuid) * "/profiles/" * string(id,base=16)
    mkpath(dirname(fname))
    
    io = IOBuffer()
    serialize(io,cert)
    bytes = take!(io)
    
    write(fname,bytes)
end


function PeaceFounderServer(config::PeaceFounderConfig,chain::BraidChain,server::Signer)

    #config = deserialize(chain,PeaceFounderConfig)

    #config = SystemConfig(deme)

    braidchain = BraidChainServer(config.braidchain,chain,server)


    certifier = Certifier(config.certifier,chain.deme,server)
    iddaemon = @async while true
        tooken,profile,cert = take!(certifier.tookencertifier.tickets)
        @show profile
        storeprofile(profile,chain.deme)
        record(config.braidchain.recorder,cert)
    end
    

    # if config.certifier==nothing
    #     certifier = nothing
    # else
    #     certifier = Certifier(config.certifier,chain.deme,server)
    #     iddaemon = @async while true
    #         tooken,profile,cert = take!(certifier.tookencertifier.tickets)
    #         @show profile
    #         storeprofile(profile,chain.deme)
    #         register(config.recorder,cert)
    #     end
    # end
    
    # mixer = Mixer(config.mixerport,chain.deme,server)
    # synchronizer = @async serve(config.syncport,chain.ledger)

    # braider = Braider(config.braider,chain.deme,server)

    ### So this is where the bug happens
    #recorder = Recorder(config.recorder,chain,braider,server)

    return PeaceFounderServer(chain,braidchain,certifier)
end


addtooken(config::PeaceFounderConfig,deme::Deme,tooken::Int,signer::Signer) = addtooken(config.certifier,deme,tooken,signer)


function ticket(config::PeaceFounderConfig,deme::Deme,tooken::Int) 
    certifier = config.certifier
    cport = certifier.certifierport
    serverid = certifier.serverid
    ticket(deme.spec,cport,serverid,tooken) # could improve API
end


