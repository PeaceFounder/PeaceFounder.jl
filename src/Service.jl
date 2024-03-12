module Service

# This is the outermost layer for the sercvice concerned with providing services for outsied world. 
# Defines how HTTP requests are processed

using ..Mapper
using ..Parser: marshal, unmarshal
using ..Model: TicketID, Digest, Pseudonym, Digest, Membership, Proposal, Vote, bytes
using ..Authorization: AuthServerMiddleware, timestamp, credential
using Dates: DateTime, Second, now
using Base: UUID
using SwaggerMarkdown

module OxygenInstance using Oxygen; @oxidise end
import .OxygenInstance: @get, @put, @post, mergeschema, serve, Request, Response

#const ROUTER = OxygenInstance.CONTEXT[].router
const ROUTER = OxygenInstance.CONTEXT[].service.router

export serve

# TODO: Put return types in swagger docs

# GET /deme # returns a current manifest file
# GET /deme/{hash}

# POST /tickets : Tuple{TicketID, DateTime, auth_code::Digest} -> Tuple{salt::Vector{UInt8}, auth_code::Digest} # resets token when repeated
# DELETE /tickets/{TicketID}
# PUT /tickets/{TicketID} : Tuple{Pseudonym, auth_code::Digest} -> Admission
# GET /tickets/{TicketID} : TicketStatus

# POST /braidchain/members : Member -> AckInclusion{ChainState}
# GET /braidchain/members : Vector{Tuple{Int, Member}}
# GET /braidchain/members?id={Pseudonym} : Tuple{Int, Member}
# GET /braidchain/members?pseudonym={Pseudonym} : Tuple{Int, Member}

# POST /braidchain/proposals : Proposal -> AckInclusion
# GET /braidcahin/proposals/{UUID} : Tuple{Int, Proposal}
# GET /braidchain/proposals : Vector{Tuple{Int, Proposal}}

# GET /braidchain/{Int}/record : Transaction
# GET /braidchain/{Int}/leaf : AckInclusion{ChainState}
# GET /braidchain/{Int}/root : AckConsistency{ChainState}
# GET /braidchain/commit : Commit{ChainState}
# GET /braidchain/tar : BraidChainArchive

# POST /pollingstation/{UUID}/votes : Vote -> CastAck
# GET /pollingstation/{UUID}/spine : Vector{Digest}
# GET /pollingstation/{UUID}/commit : Commit{BallotBoxState}
# GET /pollingstation/{UUID}/proposal : Tuple{Int, Proposal}
# GET /pollingstation/{UUID}/votes/{Int}/record : CastRecord
# GET /pollingstation/{UUID}/votes/{Int}/receipt : CastReceipt
# GET /pollingstation/{UUID}/votes/{Int}/leaf : AckInclusion{BallotBoxState}
# GET /pollingstation/{UUID}/votes/{Int}/root : AckConsistency{BallotBoxState}
# GET /pollingstation/{UUID}/tar : BallotBoxArchive
# GET /pollingstation/collectors # necessary to make a proposal


# A sketch for external braider implementation 

# GET /braider : BraiderStatus
# GET /braider/jobs : Vector{JobID}
# GET /braider/jobs/{JobID} : JobStatus
# GET /braider/jobs/{JobID}/braid : Braid
# POST /braider/jobs : BraidJobSpec -> JobID
# PUT /braider/jobs/{JobID} : Tuple{Vector{Pseudonym}, Generator} -> JobStatus


@get "/deme" function(req::Request)
    return Response(200, marshal(Mapper.get_demespec()))
end


@swagger """
/tickets:
   put:
     description: A client submits his public key ID together with a tooken. If succesful admission is returned which client could use further to enroll into braidchain.
     responses:
       '200':
         description: Successfully returned an admission.
"""
@put "/tickets" function(request::Request)

    tstamp = timestamp(request)

    if now() - tstamp > Second(60)
        return Response(401, "Old request")
    end
    
    local tokenid, ticket

    try
        tokenid = credential(request)
        ticket = Mapper.get_ticket(tokenid)
        @assert !isnothing(ticket)
    catch
        return Response(401, "Invalid Credential")
    end
    
    handler = AuthServerMiddleware(tokenid, ticket.token) do req

        id = unmarshal(req.body, Pseudonym)
        admission = Mapper.seek_admission(id, ticket.ticketid)
        
        Response(200, marshal(admission)) # will this exit the function though? This would produce response without headers.
    end
    
    return handler(request)
end


@get "/tickets/{tid}" function(req::Request, tid::String)

    ticketid = TicketID(hex2bytes(tid))

    status = Mapper.get_ticket_status(ticketid)
    
    return Response(200, marshal(status))
end


@post "/braidchain/members" function(req::Request)
    
    member = unmarshal(req.body, Membership)
    response = Mapper.enroll_member(member)

    return Response(200, marshal(response))
end


@get "/braidchain/commit" function(req::Request)
    
    response = Mapper.get_chain_commit()

    return Response(200, marshal(response))
end


@post "/braidchain/proposals" function(req::Request)

    proposal = unmarshal(req.body, Proposal)
    ack = Mapper.enlist_proposal(proposal)

    return Response(200, marshal(ack))
end


@get "/braidchain/proposals" function(req::Request)

    proposal_list = Mapper.get_chain_proposal_list()
    
    return Response(200, marshal(proposal_list))
end


@get "/braidchain/{N}/leaf" function(req::Request, N::Int)

    ack = Mapper.get_chain_ack_leaf(N)

    return Response(200, marshal(ack))
end


@get "/braidchain/{N}/root" function(req::Request, N::Int)

    ack = Mapper.get_chain_ack_root(N)

    return Response(200, marshal(ack))
end


@get "/braidchain/{N}/record" function get_chain_record(req::Request, N::Int)

    record = Mapper.get_chain_record(N)

    return Response(200, marshal(record)) # type information is important here for receiver!
end


@get "/poolingstation/{uuid_hex}/commit" function(req::Request, uuid_hex::String)
    
    uuid = UUID(uuid_hex)

    commit = Mapper.get_ballotbox_commit(uuid)
    
    return Response(200, marshal(commit))
end


@get "/poolingstation/{uuid_hex}/proposal" function(req::Request, uuid_hex::String)
    
    uuid = UUID(uuid_hex)

    proposal = Mapper.get_ballotbox_proposal(uuid)
    
    return Response(200, marshal(proposal))
end


@get "/poolingstation/{uuid_hex}/spine" function(req::Request, uuid_hex::String)
    
    uuid = UUID(uuid_hex)

    spine = Mapper.get_ballotbox_spine(uuid)
    
    return Response(200, marshal(spine))
end


@post "/poolingstation/{uuid_hex}/votes" function cast_vote(req::Request, uuid_hex::String)
    
    uuid = UUID(uuid_hex)

    vote = unmarshal(req.body, Vote)
    ack = Mapper.cast_vote(uuid, vote)

    return Response(200, marshal(ack))
end


@get "/poolingstation/{uuid_hex}/votes/{N}/record" function(req::Request, uuid_hex::String, N::Int)
    
    uuid = UUID(uuid_hex)
    record = Mapper.get_ballotbox_record(uuid, N)
    
    return Response(200, marshal(record))
end


@get "/poolingstation/{uuid_hex}/votes/{N}/receipt" function get_ballotbox_receipt(req::Request, uuid_hex::String, N::Int)

    uuid = UUID(uuid_hex)
    receipt = Mapper.get_ballotbox_receipt(uuid, N)

    return Response(200, marshal(receipt))
end


@get "/poolingstation/{uuid_hex}/votes/{N}/leaf" function get_ballotbox_leaf(req::Request, uuid_hex::String, N::Int)

    uuid = UUID(uuid_hex)
    ack = Mapper.get_ballotbox_ack_leaf(uuid, N)

    return Response(200, marshal(ack))
end


@get "/poolingstation/{uuid_hex}/votes/{N}/root" function get_ballotbox_root(req::Request, uuid_hex::String, N::Int)

    uuid = UUID(uuid_hex)
    ack = Mapper.get_ballotbox_ack_root(uuid, N)

    return Response(200, marshal(ack))
end


# title and version are required
info = Dict("title" => "PeaceFounder API", "version" => "0.4.0")
openApi = OpenAPI("3.0", info)
swagger_document = build(openApi)
  
# # merge the SwaggerMarkdown schema with the internal schema
OxygenInstance.mergeschema(swagger_document)


end
