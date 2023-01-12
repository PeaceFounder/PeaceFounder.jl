module Service

# This is the outermost layer for the sercvice concerned with providing services for outsied world. 

# Defines how HTTP requests are processed

using Infiltrator

using ..Mapper
using ..Parser: marshal, unmarshal

using HTTP: Request, Response, HTTP
using ..Model: TicketID, Digest, Pseudonym, Digest
using Dates: DateTime

const ROUTER = HTTP.Router()


# GET /manifest # returns a current manifest file
# GET /manifest/{hash}

# POST /tickets : Tuple{TicketID, Digest} -> Tuple{salt::Vector{UInt8}, auth_code::Digest}  # resets token when repeated
# DELETE /tickets/{TicketID} : auth_code::Digest -> Bool
# PUT /tickets/{TicketID} : Tuple{Pseudonym, token::BigInt} -> Admission
# GET /tickets/{TicketID}/status : Bool # whether token is active
# GET /tickets/{TicketID}/admission : Admission

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

# This way I will be able to use structtypes 


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

HTTP.register!(ROUTER, "POST", "/tickets/{ticketid}", seek_admission)




end
