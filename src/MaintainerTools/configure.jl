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
