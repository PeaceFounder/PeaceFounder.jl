module PeaceFounder

using Sockets
import Serialization
import PeaceVote
using PeaceVote: Voter, Signer
using PeaceVote: Certificate, Ticket, Braid, Vote, voters!

###

import Base.sync_varname
import Base.@async

macro async(expr)

    tryexpr = quote
        try
            $expr
        catch err
            @warn "error within async" exception=err # line $(__source__.line):
        end
    end

    thunk = esc(:(()->($tryexpr)))

    var = esc(sync_varname)
    quote
        local task = Task($thunk)
        if $(Expr(:isdefined, var))
            push!($var, task)
        end
        schedule(task)
        task
    end
end

### System definitions (part of PeaceFounder).

function save(fname,x) 
    @assert !isfile(fname) "File $fname already exists."
    Serialization.serialize(fname,x)
end

#const CONFIG_DIR = dirname(dirname(@__FILE__))
# For simplicituy I could make entries a dictionaries.
struct RouteRecords
    ballotmixers ### the server which mixes stuff
    onionnodes ### for users to be able to deliver the messages anonymously
    relays ### for being able to reach the member with in the community 
end

# RouteRecords(fname) = Serialization.deserialize(fname)
# RouteRecords() = RouteRecords(dirname(dirname(@__FILE__)) * "/routerecords.config")
# save(x::RouteRecords) = save(dirname(dirname(@__FILE__)) * "/routerecords.config",x)

# struct Braider
#     port
#     N
# #    gateid 
# #    mixerid
# end

### Contains all necessary information to take part in the braidchain. 
struct BraidChainConfig
    membersca ## certificate authorithy which can register the member
    maintainer ## https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work. The main part perhaps would be to issue corrections to the braidchain. For example invalidate braid, because someone had stolen the key. 
    registratorport
    votingport
    proposalport
    #mixerport 
    # ftpport ### this one has as passive role as 
    #braider::Braider
    braider ### each of theese things do have their own configureation under them. Could contain multiple ones which are accordingly started if necesary. More like a configuration here.
end


### Conviniance methods for loading data

### Sign can be 

function inout(uuid,msgs,signatures,verify,id)
    input = Set()
    for s in signatures
        @assert verify(msgs,s) "braid with $uuid is not valid"
        push!(input,id(s))
    end
    
    output = Set(msgs)
    
    @assert length(input)==length(output)

    return input,output
end

function loadmembers(datadir,sc::BraidChainConfig)
    members = Set()
    for fname in readdir(datadir)
        time = mtime(datadir * fname)
        cert = Serialization.deserialize(datadir * fname)
        
        memberid, signerid = PeaceVote.unwrap(cert)
        @assert signerid!=nothing && signerid in sc.membersca "certificate $fname is not valid"
        push!(members,memberid)
    end
    return members
end

function loadtickets!(date,messages,datadir)
    for fname in readdir(datadir)
        time = mtime(datadir * fname)
        cert = Serialization.deserialize(datadir * fname)

        memberid, signerid = PeaceVote.unwrap(cert)
        ticket = PeaceVote.Ticket(signerid...,memberid.id)
        push!(date,time)
        push!(messages,ticket)
    end
end

function loadbraids!(date,messages,datadir,verify,id)
    for fname in readdir(datadir)
        time = mtime(datadir * fname)
        ballot = Serialization.deserialize(datadir * fname)

        input,output = inout(fname,ballot...,verify,id)
        braid = PeaceVote.Braid(fname,nothing,input,output) # bcid yet to be implemented. A function for a common message could be nice for the SynchronicBallot.

        push!(date,time)
        push!(messages,braid)
    end
end

function loadvotes!(date,messages,datadir,verify,id)
    for fname in readdir(datadir)
        time = mtime(datadir * fname)
        msg,signature = Serialization.deserialize(datadir * fname)

        @assert verify(msg,signature) "Vote $fname invalid."
        vote = Vote(fname,id(signature),msg)

        push!(date,time)
        push!(messages,vote)
    end
end

function loaddata(datadir,verify,id)
    date = []
    messages = []
    
    loadtickets!(date,messages,datadir * "members/")
    loadbraids!(date,messages,datadir * "braids/",verify,id)
    loadvotes!(date,messages,datadir * "votes/",verify,id)

    sp = sortperm(date)

    return messages[sp]
end

### Server daemons

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

            if signerid!=nothing && validate(signerid)
                put!(messages,envelope)
                Serialization.serialize(socket,true)
            else
                Serialization.serialize(socket,"The signer of the certificate is not in the trustset")
            end
        end
    end
    
    Registrator(server,daemon,messages)
end

struct BraidChain
    registrator
    voterecorder
    proposalreceiver
    braider
    members
    voters
    daemon
end

### config specifies the ports. tp specifies which ballotboxes one needs to connect with.
### instead of sign I need to have a signer type which looks through what needs to be served

function BraidChain(datadir,config::BraidChainConfig,ballotserver::Function,unwrap::Function,verify::Function,id::Function,signer::Signer) #,sign::Function) 
    
    mkpath(datadir)
    mkpath(datadir * "members")
    mkpath(datadir * "braids")
    mkpath(datadir * "votes")
    mkpath(datadir * "proposals")

    ### Loading stuff ###
    
    members = loadmembers(datadir * "members/",config)
    messages = loaddata(datadir,verify,id)
    
    voters = Set()
    voters!(voters,messages)

    ### Starting server apps ###
    
    registrator = Registrator(config.registratorport,PeaceVote.unwrap,x -> x in config.membersca)
    voterecorder = Registrator(config.votingport,unwrap,x -> x in voters)
    proposalreceiver = Registrator(config.proposalport,unwrap,x -> x in members)
    

    braider = ballotserver(config.braider,voters,signer)

    daemon = @async @sync begin
        @async while true
            cert = take!(registrator.messages)
            
            push!(members,cert.data.id)
            push!(voters,cert.data.id)
            
            save("$datadir/members/$(cert.data.id)",cert)
        end

        @async while true
            ballot = take!(braider.ballots) # ballot
            uuid = hash(ballot) ### no need for it to be cryptographical

            input,output = inout(uuid,ballot...,verify,id) # I could construct a Braid
            braid = PeaceVote.Braid(hash(ballot),nothing,input,output)
            PeaceVote.voters!(voters,braid)

            save("$datadir/braids/$uuid",ballot) # ballot
        end

        @async while true
            vote = take!(voterecorder.messages)
            uuid = hash(vote)
            save("$datadir/votes/$uuid",vote)
        end

        @async while true
            proposal = take!(proposalreceiver.messages)
            uuid = hash(proposal)
            save("$datadir/proposals/$uuid",proposal)
        end

    end

    BraidChain(registrator,voterecorder,proposalreceiver,braider,members,voters,daemon)
end

### User methods

function register(sc::BraidChainConfig,certificate::Certificate)
    
    memberid, signerid = PeaceVote.unwrap(certificate)
    @assert signerid!=nothing
    @assert signerid in sc.membersca

    socket = connect(sc.registratorport)

    # ### First one validates the certificate in the usr side. 
    Serialization.serialize(socket,certificate)
    
    return Serialization.deserialize(socket)
end

function vote(sc::BraidChainConfig,msg,signer::Voter)
    socket = connect(sc.votingport)
    Serialization.serialize(socket,(msg,signer.sign(msg)))
end

function propose(sc::BraidChainConfig,msg,options,signature)
    socket = connect(sc.proposalport)
    Serialization.serialize(socket,((msg,options),signature))
end

end # module
