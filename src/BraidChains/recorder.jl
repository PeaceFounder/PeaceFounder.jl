### config specifies the ports. tp specifies which ballotboxes one needs to connect with.
### instead of sign I need to have a signer type which looks through what needs to be served



function binary(x)
    io = IOBuffer()
    Serialization.serialize(io,x)
    return take!(io)
end

import Synchronizers.Record
Record(fname::AbstractString,x) = Record(fname,binary(x))

struct Registrator
    server
    daemon
    messages # a Channel
end

function Registrator(port,unwrap::Function,validate::Function)
    server = listen(port)
    messages = Channel()
    
    daemon = @async while true
        socket = accept(server)
        @async begin
            envelope = Serialization.deserialize(socket)
            memberid, signerid = unwrap(envelope)

            if validate(signerid)
                put!(messages,envelope)
            end
        end
    end
    
    Registrator(server,daemon,messages)
end

struct BraidChainServer # RecorderConfig
    registrator
    voterecorder
    proposalreceiver
    braider 
    members
    daemon
end


### Recorder or BraidChainRecorder
function BraidChainServer(config::BraidChainConfig,deme::ThisDeme,braider::Braider,signer::Signer) 
    
    # This part belongs to MaintainerTools
    # systemconfig = SystemConfig(deme)
    # config = systemconfig.braidchain

    notary = deme.notary
    ledger = deme.ledger

    messages = braidchain(deme)

    members = PeaceVote.members(messages,config.membersca)
    voters!(braider.voters,messages) ### I could update the braider here

    allvoters = Set()
    voters!(allvoters,messages)

    ### Starting server apps ###
    
    registrator = Registrator(config.registratorport,PeaceVote.unwrap,x -> x in config.membersca)
    voterecorder = Registrator(config.votingport,x->unwrap(x,notary),x -> x in allvoters)
    proposalreceiver = Registrator(config.proposalport,x->unwrap(x,notary),x -> x in members)

    daemon = @async @sync begin
        @async while true
            cert = take!(registrator.messages)
            
            id = cert.data.id

            push!(members,id)
            push!(braider.voters,id)
            push!(allvoters,id)
            
            record = Record("members/$id",cert)
            push!(ledger,record)
        end

        @async while true
            ballot = take!(braider)
            uuid = hash(ballot,deme.notary) 

            input,output = inout(uuid,ballot...,deme.notary) # I could construct a Braid
            braid = PeaceVote.Braid(uuid,nothing,input,output)
            PeaceVote.voters!(braider.voters,braid)

            PeaceVote.addvoters!(allvoters,braid)

            record = Record("braids/$uuid",ballot)
            push!(ledger,record)
        end

        @async while true
            vote = take!(voterecorder.messages)
            uuid = Base.hash(vote)

            record = Record("votes/$uuid",vote)
            push!(ledger,record)
        end

        @async while true
            proposal = take!(proposalreceiver.messages)
            uuid = Base.hash(proposal)
            
            record = Record("proposals/$uuid",proposal)
            push!(ledger,record)
        end

    end

    BraidChainServer(registrator,voterecorder,proposalreceiver,braider,members,daemon)
end



function register(config::BraidChainConfig,certificate::Certificate)
    socket = connect(config.registratorport)
    Serialization.serialize(socket,certificate)
    #close(socket)
end

# function register(deme::ThisDeme,certificate::Certificate)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     register(config,certificate)
# end

function vote(config::BraidChainConfig,msg,signer::Signer)
    socket = connect(config.votingport)
    Serialization.serialize(socket,(msg,sign(msg,signer)))
    #close(socket)
end

# function vote(deme::ThisDeme,msg,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     vote(config,msg,signer)
# end

function propose(config::BraidChainConfig,msg,options,signer::Signer)
    socket = connect(config.proposalport)
    Serialization.serialize(socket,((msg,options),sign((msg,options),signer)))
    #close(socket)
end


# function propose(deme::ThisDeme,msg,options,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     propose(config,msg,options,signer)
# end
