### config specifies the ports. tp specifies which ballotboxes one needs to connect with.
### instead of sign I need to have a signer type which looks through what needs to be served

# The data format then also could be implemented outside BraidChains module!

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
            envelope = deserialize(socket)
            memberid, signerid = unwrap(envelope)

            if validate(signerid)
                put!(messages,envelope)
            end
        end
    end
    
    Registrator(server,daemon,messages)
end

struct Recorder # RecorderConfig
    registrator
    voterecorder
    proposalreceiver
    braider 
    members
    daemon
end


### Recorder or BraidChainRecorder
function Recorder(config::RecorderConfig,deme::ThisDeme,braider::Braider,signer::Signer) 
    
    # This part belongs to MaintainerTools
    # systemconfig = SystemConfig(deme)
    # config = systemconfig.braidchain

    notary = deme.notary
    ledger = deme.ledger 
    
    
    messages = BraidChain(deme).records

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


            record!(ledger,"members/$id",cert) # I could make a function record!
            #push!(ledger,record)
        end

        @async while true
            ballot = take!(braider)
            uuid = hash(ballot,deme.notary) 

            input,output = inout(uuid,ballot...,deme.notary) # I could construct a Braid
            braid = PeaceVote.Braid(uuid,nothing,input,output)
            PeaceVote.voters!(braider.voters,braid)

            PeaceVote.addvoters!(allvoters,braid)

            record!(ledger,"braids/$uuid",ballot)
            #push!(ledger,record)
        end

        @async while true
            vote = take!(voterecorder.messages)
            uuid = hash(vote,deme.notary)

            record!(ledger,"votes/$uuid",vote)
            #push!(ledger,record)
        end

        @async while true
            proposal = take!(proposalreceiver.messages)
            uuid = hash(proposal,deme.notary)
            
            record!(ledger,"proposals/$uuid",proposal)
            #push!(ledger,record)
        end

    end

    Recorder(registrator,voterecorder,proposalreceiver,braider,members,daemon)
end



function register(config::RecorderConfig,certificate::Certificate)
    socket = connect(config.registratorport)
    serialize(socket,certificate)
    #close(socket)
end

# function register(deme::ThisDeme,certificate::Certificate)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     register(config,certificate)
# end

function vote(config::RecorderConfig,msg,signer::Signer)
    socket = connect(config.votingport)
    serialize(socket,(msg,sign(msg,signer)))
    #close(socket)
end

# function vote(deme::ThisDeme,msg,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     vote(config,msg,signer)
# end

function propose(config::RecorderConfig,msg,options,signer::Signer)
    socket = connect(config.proposalport)
    serialize(socket,((msg,options),sign((msg,options),signer)))
    #close(socket)
end


# function propose(deme::ThisDeme,msg,options,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     propose(config,msg,options,signer)
# end
