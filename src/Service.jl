module Service

# This is the outermost layer for the sercvice concerned with providing services for outsied world. 
# Defines how HTTP requests are processed

using Infiltrator

using ..Mapper
using ..Parser: marshal, unmarshal
using Base: UUID

using HTTP: Request, Response, HTTP
using ..Model: TicketID, Digest, Pseudonym, Digest, Member, Proposal, Vote
using Dates: DateTime

const ROUTER = HTTP.Router()


# POST /braidchain/members : Member -> AckInclusion
# GET /braidchain/members : Vector{Tuple{Int, Member}}
# GET /braidchain/members?id={Pseudonym} : Tuple{Int, Member}
# GET /braidchain/members?pseudonym={Pseudonym} : Tuple{Int, Member}

# POST /braidchain/proposals : Proposal -> AckInclusion
# GET /braidcahin/proposals/{UUID} : Tuple{Int, Proposal}
# GET /braidchain/proposals : Vector{Tuple{Int, Proposal}}

# GET /braidchain/{Int}/record : Transaction
# GET /braidchain/{Int}/leaf : AckInclusion
# GET /braidchain/{Int}/root : AckConsistency
# GET /braidchain/commit : Commit
# GET /braidchain/tar : BraidChainArchive

# POST /pollingstation/{UUID}/votes : Vote -> AckInclusion
# GET /pollingstation/{UUID}/spine : Vector{Digest}
# GET /pollingstation/{UUID}/commit : Commit{BallotBoxState}
# GET /pollingstation/{UUID}/proposal : Tuple{Int, Proposal}
# GET /pollingstation/{UUID}/votes/{Int}/record : Vote
# GET /pollingstation/{UUID}/votes/{Int}/leaf : AckInclusion
# GET /pollingstation/{UUID}/votes/{Int}/root : AckConsistency
# GET /pollingstation/{UUID}/tar : BallotBoxArchive
# GET /pollingstation/collectors # necessary to make a proposal


get_deme(req::Request) = Response(200, marshal(Mapper.get_deme()))
HTTP.register!(ROUTER, "GET", "/deme", get_deme)


function enlist_ticket(req::Request) 
    
    ticketid, timestamp, auth_code = unmarshal(req.body, Tuple{TicketID, DateTime, Digest})
    response = Mapper.enlist_ticket(ticketid, timestamp, auth_code)

    return Response(200, marshal(response))
end

HTTP.register!(ROUTER, "POST", "/tickets", enlist_ticket)


"""
A client submits his public key ID together with a tooken. If succesful admission is returned which client could use further to enroll into braidchain.
"""
function seek_admission(req::Request) 

    tid = HTTP.getparam(req, "ticketid")
    ticketid = TicketID(hex2bytes(tid))

    id, auth_code = unmarshal(req.body, Tuple{Pseudonym, Digest})
    response = Mapper.seek_admission(id, ticketid, auth_code)
    
    return Response(200, marshal(response))
end

HTTP.register!(ROUTER, "PUT", "/tickets/{ticketid}", seek_admission)

function get_ticket_status(req::Request)

    tid = HTTP.getparam(req, "ticketid")
    ticketid = TicketID(hex2bytes(tid))

    status = Mapper.get_ticket_status(ticketid)
    
    return Response(200, marshal(status))
end

HTTP.register!(ROUTER, "GET", "/tickets/{ticketid}", get_ticket_status)


function enroll_member(req::Request)
    
    member = unmarshal(req.body, Member)
    response = Mapper.enroll_member(member)

    return Response(200, marshal(response))
end

HTTP.register!(ROUTER, "POST", "/braidchain/members", enroll_member)


function get_chain_commit(req::Request)
    
    response = Mapper.get_chain_commit()

    return Response(200, marshal(response))
end

HTTP.register!(ROUTER, "GET", "/braidchain/commit", get_chain_commit)


function enlist_proposal(req::Request)

    proposal = unmarshal(req.body, Proposal)
    ack = Mapper.enlist_proposal(proposal)

    return Response(200, marshal(ack))
end

HTTP.register!(ROUTER, "POST", "/braidchain/proposals", enlist_proposal)


function get_proposal_list(req::Request)

    proposal_list = Mapper.get_chain_proposal_list()
    
    return Response(200, marshal(proposal_list))
end

HTTP.register!(ROUTER, "GET", "/braidchain/proposals", get_proposal_list)


function get_chain_leaf(req::Request)

    N = parse(Int, HTTP.getparam(req, "N"))
    ack = Mapper.get_chain_ack_leaf(N)

    return Response(200, marshal(ack))
end

HTTP.register!(ROUTER, "GET", "/braidchain/{N:[0-9]+}/leaf", get_chain_leaf)


function get_chain_root(req::Request)

    N = parse(Int, HTTP.getparam(req, "N"))
    ack = Mapper.get_chain_ack_root(N)

    return Response(200, marshal(ack))
end

HTTP.register!(ROUTER, "GET", "/braidchain/{N:[0-9]+}/root", get_chain_root)


function get_chain_record(req::Request)

    N = parse(Int, HTTP.getparam(req, "N"))
    record = Mapper.get_chain_record(N)

    return Response(200, marshal(record)) # type information is important here for receiver!
end

HTTP.register!(ROUTER, "GET", "/braidchain/{N:[0-9]+}/record", get_chain_record)


function get_ballotbox_commit(req::Request)
    
    uuid_hex = HTTP.getparam(req, "uuid")
    uuid = UUID(uuid_hex)

    commit = Mapper.get_ballotbox_commit(uuid)
    
    return Response(200, marshal(commit))
end

HTTP.register!(ROUTER, "GET", "/poolingstation/{uuid}/commit", get_ballotbox_commit)


function get_ballotbox_proposal(req::Request)
    
    uuid_hex = HTTP.getparam(req, "uuid")
    uuid = UUID(uuid_hex)

    proposal = Mapper.get_ballotbox_proposal(uuid)
    
    return Response(200, marshal(proposal))
end

HTTP.register!(ROUTER, "GET", "/poolingstation/{uuid}/proposal", get_ballotbox_proposal)



function cast_vote(req::Request)
    
    uuid_hex = HTTP.getparam(req, "uuid")
    uuid = UUID(uuid_hex)

    vote = unmarshal(req.body, Vote)
    ack = Mapper.cast_vote(uuid, vote)

    return Response(200, marshal(ack))
end

HTTP.register!(ROUTER, "POST", "/poolingstation/{uuid}/votes", cast_vote)





end
