### config specifies the ports. tp specifies which ballotboxes one needs to connect with.
### instead of sign I need to have a signer type which looks through what needs to be served

# The data format then also could be implemented outside BraidChains module!

struct Registrator
    server
    daemon
    messages # a Channel
end

function Registrator(port,verify::Function,validate::Function)
    server = listen(port)
    messages = Channel()
    
    daemon = @async while true
        socket = accept(server)
        @async begin
            envelope = deserialize(socket)
            signerid = verify(envelope)
            #memberid, signerid = unwrap(envelope)

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


extverify(x::Certificate{T},notary::Notary) where T <: AbstractID = PeaceVote.verify(x,notary)
extverify(x::Envelope{Certificate{T}},notary::Notary) where T <: AbstractID = PeaceVote.verify(x)

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
    ### With envelope type now I can easally add external certifiers
    registrator = Registrator(config.registratorport,x->extverify(x,notary),x -> x in config.membersca)
    voterecorder = Registrator(config.votingport,x->PeaceVote.verify(x,notary),x -> x in allvoters)
    proposalreceiver = Registrator(config.proposalport,x->PeaceVote.verify(x,notary),x -> x in members)

    daemon = @async @sync begin
        @async while true
            cert = take!(registrator.messages)
            
            id = cert.document.id

            push!(members,id)
            push!(braider.voters,id)
            push!(allvoters,id)


            record!(ledger,"members/$(id.id)",cert) # I could make a function record!
            #push!(ledger,record)
        end

        @async while true
            braid = take!(braider)
            uuid = hash(braid,deme.notary) 
            consbraid = Consensus(braid,deme.notary)
            
            ### We have different types here. I could move everything to references in future.
            input = unique(consbraid.references)
            output = unique(consbraid.document.ids)
            @assert length(input)==length(output)
            #input,output = inout(uuid,ballot...,deme.notary) # I could construct a Braid
            
            #braid = PeaceVote.Braid(uuid,nothing,input,output)
            PeaceVote.voters!(braider.voters,input,output)
            #PeaceVote.voters!(braider.voters,braid)

            #PeaceVote.addvoters!(allvoters,braid)
            PeaceVote.addvoters!(allvoters,input,output)

            record!(ledger,"braids/$uuid",braid)
            #push!(ledger,record)
        end

        @async while true
            vote = take!(voterecorder.messages)
            uuid = hash(vote,deme.notary)

            record!(ledger,"votes/$uuid",vote)
            #push!(ledger,record)
        end

        @async while true
            @show proposal = take!(proposalreceiver.messages)
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

function vote(config::RecorderConfig,msg::AbstractVote,signer::Signer)
    socket = connect(config.votingport)
    cert = Certificate(msg,signer)
    serialize(socket,cert)
    #close(socket)
end

# function vote(deme::ThisDeme,msg,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     vote(config,msg,signer)
# end

function propose(config::RecorderConfig,proposal::AbstractProposal,signer::Signer)
    socket = connect(config.proposalport)
    cert = Certificate(proposal,signer)
    serialize(socket,cert)
    #close(socket)
end


# function propose(deme::ThisDeme,msg,options,signer::Signer)
#     systemconfig = SystemConfig(deme)
#     config = systemconfig.braidchain
#     propose(config,msg,options,signer)
# end
