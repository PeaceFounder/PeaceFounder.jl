module Resource
# Defines how HTTP requests are processed

using ..Mapper
using JSON3
using HTTP

using HTTP: Request, Response
using ..Model

const ROUTER = HTTP.Router()


# GET /manifest # returns a current manifest file
# GET /manifest/{hash}

# POST /tickets : TicketID -> token::BigInt # resets token when repeated
# DELETE /tickets/{TicketID}
# PUT /tickets/{TicketID} : Tuple{Pseudonym, token::BigInt} -> Admission
# GET /tickets/{TicketID}/status # whether token is active
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



function new_ticket(req::Reuset) end # returns a formid
HTTP.register!(ROUTER, "POST", "/tickets", new_ticket)


"""
A client submits his public key ID together with a tooken. If succesful admission is returned which client could use further to enroll into braidchain.
"""
function seek_admission(req::Reaquest) end
HTTP.register!(ROUTER, "POST", "/tickets/{ticketid}", seek_admission)


###############


function enroll_member(req::Request)

    m = JSON3.read(req.body, Model.Member)
    Mapper.enroll_member(m)
    return Response(200, "")

end

HTTP.register!(ROUTER, "POST", "/members", post_member)


function get_member_list(req::Request)

    list = Mapper.get_members()
    body = JSON3.write(list)
    return Response(200, body)

end

HTTP.register!(ROUTER, "GET", "/members", get_members)


function get_member(req::Request)

    id = HTTP.getparams(req)["id"]
    
    bytes = Model.base16decode(id)

    p = Model.Pseudonym(bytes)
    
    member = Mapper.get_member(p)

    body = JSON3.write(member)

    return Response(200, body)
end


HTTP.register!(ROUTER, "GET", "/members/{id}", get_member)






function post_proposal(req::Request) end
HTTP.register!(ROUTER, "POST", "/proposals", post_proposal)


function get_proposal_catalog(req::Request) end
HTTP.register!(ROUTER, "GET", "/proposals", get_proposal_catalog)
HTTP.register!(ROUTER, "GET", "/proposals/{uuid}/?status={status}", get_proposals_catalog)
# status = approved = planned + active + closed, pending, declined
# @enum ProposalStatus APPROVED ACTIVE CLOSED PLANNED PENDING DECLINED


function get_proposal(req::Request) end
HTTP.register!(ROUTER, "GET", "/proposals/{uuid}", get_proposal)


"""
If the proposal is signed by the guardian it gets added to the braidchain.
"""
function update_proposal(req::Request) end
HTTP.register!(ROUTER, "PUT", "/proposals/{uuid}", update_proposal)


"""
Returns a list of vote hashes and a treehash with approval
"""
function get_vote_register(req::Request) end
HTTP.register!(ROUTER, "GET", "/proposals/{uuid}/votes", get_vote_register) # get_votes_summary


function get_vote(req::Request) end # may be authetificated during ellections and available to everyone after them
HTTP.register!(ROUTER, "GET", "/proposals/{uuid}/votes/{n}", get_vote) 


"""
Returns assurance that the vote is included in the chain. A simple signature from colelctor would work fine here.
"""
function post_vote(req::Request) end
HTTP.register!(ROUTER, "POST", "/proposals/{uuid}/votes", post_vote)


function get_result(req::Request) end
HTTP.register!(ROUTER, "POST", "/proposals/{uuid}/result", get_result)



function get_braidchain_summary(req::Request)

    summary = Mapper.get_braidchain_summary()

    body = JSON3.write(summary)

    return Response(200, body)
end

HTTP.register!(ROUTER, "GET", "/braidchain", get_braidchain_summary)


function get_braidchain_element(req::Request) end
HTTP.register!(ROUTER, "GET", "/braidchain/{n}", get_braidchain_element)




"""
Defines
    - cryptographic group used
    - avialable proposal types
    - hash function
    - the guardian pseudonym
    - the braider pseudonym
    - the recruiter pseudonym
    - date
    - previous manifest hash
    - trusted guardians from other communities
"""
function get_manifest(req::Request) end
HTTP.register!(ROUTER, "GET", "/manifest", get_manifest)


function get_manifest_entry(req::Request) end
HTTP.register!(ROUTER, "GET", "/manifest/{hash}", get_manifest_entry))  # The canonicalization must be fixed by PeaceFounder wheras the hash function could be specified by signup form.


### BRAIDER 


function get_braider_summary(req::Request) end
HTTP.register!(ROUTER, "GET", "/braider", get_braider_summary)

### The following functions are behind authorization

function post_braider_job(req::Request) end
HTTP.register!(ROUTER, "POST", "/braider/jobs", post_braider_job)


function get_braider_job_history(req::Request) end
HTTP.register!(ROUTER, "GET", "/braider/jobs", get_braider_job_history)


function get_braider_job(req::Request) end
HTTP.register!(ROUTER, "GET", "/braider/jobs/{jobid}", get_braider_job)



end
