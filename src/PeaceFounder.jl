module PeaceFounder

using Sockets
import Serialization
import PeaceVote
using PeaceVote: Signer
using PeaceVote: Certificate, Ticket, Braid, Proposal, Vote, voters!

using Synchronizers: Record, Ledger
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

#const CONFIG_DIR = dirname(dirname(@__FILE__))
# For simplicituy I could make entries a dictionaries.
# struct RouteRecords
#     ballotmixers ### the server which mixes stuff
#     onionnodes ### for users to be able to deliver the messages anonymously
#     relays ### for being able to reach the member with in the community 
# end

# RouteRecords(fname) = Serialization.deserialize(fname)
# RouteRecords() = RouteRecords(dirname(dirname(@__FILE__)) * "/routerecords.config")
# save(x::RouteRecords) = save(dirname(dirname(@__FILE__)) * "/routerecords.config",x)

### Contains all necessary information to take part in the braidchain. 
struct BraidChainConfig
    membersca ## certificate authorithy which can register the member
    maintainer ## https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work. The main part perhaps would be to issue corrections to the braidchain. For example invalidate braid, because someone had stolen anonymous identity. 
    registratorport
    votingport
    proposalport
    braider ### each of theese things do have their own configureation under them. Could contain multiple ones which are accordingly started if necesary. More like a configuration here.
end

### Conviniance methods for loading data

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

### Now I need to test that I can read this thing.
function braidchain(ledger::Ledger,verify::Function,id::Function)
    messages = []
    for record in ledger.records
        if dirname(record.fname)=="members"

            cert = Serialization.deserialize(IOBuffer(record.data))
            memberid, signerid = PeaceVote.unwrap(cert)
            ticket = PeaceVote.Ticket(signerid...,memberid.id)
            push!(messages,ticket)

        elseif dirname(record.fname)=="braids"

            ballot = Serialization.deserialize(IOBuffer(record.data))
            input,output = inout(basename(record.fname),ballot...,verify,id)
            braid = PeaceVote.Braid(basename(record.fname),nothing,input,output) 
            push!(messages,braid)

        elseif dirname(record.fname)=="votes"

            msg,signature = Serialization.deserialize(IOBuffer(record.data))
            @assert verify(msg,signature) "Invalid vote."
            vote = Vote(basename(record.fname),id(signature),msg)
            push!(messages,vote)

        elseif dirname(record.fname)=="proposals"

            (msg,options),signature = Serialization.deserialize(IOBuffer(record.data))
            @assert verify((msg,options),signature) "Invalid proposal."
            proposal = Proposal(basename(record.fname),id(signature),msg,options)
            push!(messages,proposal)

        end
    end
    return messages
end

braidchain(datadir::AbstractString,verify::Function,id::Function) = braidchain(Ledger(datadir),verify,id)

### This function probably belongs to PeaceVote
function loadmembers(braidchain,ca)
    members = Set()
    for item in braidchain
        if typeof(item)==Ticket
            @assert (item.uuid,item.cid) in ca "certificate for $(item.id) is not valid"
            push!(members,item.id)
        end
    end
    return members
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

function binary(x)
    io = IOBuffer()
    Serialization.serialize(io,x)
    return take!(io)
end

import Synchronizers.Record
Record(fname::AbstractString,x) = Record(fname,binary(x))

# I could substitute datadir with Ledger and then give serving ability to the Community!
function BraidChain(ledger::Ledger,config::BraidChainConfig,ballotserver::Function,unwrap::Function,verify::Function,id::Function,signer::Signer) #,sign::Function) 

    messages = braidchain(ledger,verify,id)

    members = loadmembers(messages,config.membersca)
    
    voters = Set()
    voters!(voters,messages)

    allvoters = Set()
    voters!(allvoters,messages)

    ### Starting server apps ###
    
    registrator = Registrator(config.registratorport,PeaceVote.unwrap,x -> x in config.membersca)
    voterecorder = Registrator(config.votingport,unwrap,x -> x in allvoters)
    proposalreceiver = Registrator(config.proposalport,unwrap,x -> x in members)

    braider = ballotserver(config.braider,voters,signer)

    daemon = @async @sync begin
        @async while true
            cert = take!(registrator.messages)
            
            push!(members,cert.data.id)
            push!(voters,cert.data.id)

            push!(allvoters,cert.data.id)
            
            record = Record("members/$(cert.data.id)",cert)
            push!(ledger,record)
        end

        @async while true
            ballot = take!(braider.ballots) # ballot
            uuid = hash(ballot) ### no need for it to be cryptographical

            input,output = inout(uuid,ballot...,verify,id) # I could construct a Braid
            braid = PeaceVote.Braid(hash(ballot),nothing,input,output)
            PeaceVote.voters!(voters,braid)

            PeaceVote.addvoters!(allvoters,braid)

            record = Record("braids/$uuid",ballot)
            push!(ledger,record)
        end

        @async while true
            vote = take!(voterecorder.messages)
            uuid = hash(vote)

            record = Record("votes/$uuid",vote)
            push!(ledger,record)
        end

        @async while true
            proposal = take!(proposalreceiver.messages)
            uuid = hash(proposal)
            
            record = Record("proposals/$uuid",proposal)
            push!(ledger,record)
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

function vote(sc::BraidChainConfig,msg,signer::Signer)
    socket = connect(sc.votingport)
    Serialization.serialize(socket,(msg,signer.sign(msg)))
end

function propose(sc::BraidChainConfig,msg,options,signature)
    socket = connect(sc.proposalport)
    Serialization.serialize(socket,((msg,options),signature))
end

end # module
