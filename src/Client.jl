module Client
# Methods to interact with HTTP server

using Infiltrator

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, Hash, AckConsistency, AckInclusion, CastAck, Deme, Signer, TicketStatus, Commit, ChainState

using ..Model: id, hasher, pseudonym, isbinding, generator, isadmitted

using HTTP: Router, Request, Response, Handler, HTTP, iserror, StatusError

using JSON3
using Dates


using ..Parser: marshal, unmarshal

using ..Model: base16encode, base16decode


post(route::String, target::String, body) = HTTP.post(route * target, body)
put(route::String, target::String, body) = HTTP.put(route * target, body)

function request(method::String, router::Router, target::String, body::Vector{UInt8})

    request = Request(method, target, [], body)
    response = router(request)

    iserror(response) && throw(StatusError(response.status, method, target, response))

    return response
end


request(method::String, route::String, target::String, body::Vector{UInt8}) = HTTP.request(method, route * target, body)


post(route, target, body) = request("POST", route, target, body)
put(route, target, body) = request("PUT", route, target, body)
get(route, target) = request("GET", route, target, UInt8[])



function get_deme(router::Router)

    response = get(router, "/deme")
    deme = unmarshal(response.body, Deme)

    return deme
end


function enlist_ticket(router::Router, ticketid::TicketID, hmac::HMAC)

    timestamp = Dates.now()
    ticket_auth_code = Model.auth(ticketid, timestamp, hmac)
    body = marshal((ticketid, timestamp, ticket_auth_code))

    response = post(router, "/tickets", body)

    salt, salt_auth_code = unmarshal(response.body, Tuple{Vector{UInt8}, Digest})

    @assert isbinding(ticketid, salt, salt_auth_code, hmac)

    return Model.token(ticketid, salt, hmac)
end


function seek_admission(router::Router, id::Pseudonym, ticketid::TicketID, token::Digest, hasher::Hash)

    auth_code = Model.auth(id, token, hasher)
    body = marshal((id, auth_code))
    tid = bytes2hex(bytes(ticketid))
    response = put(router, "/tickets/$tid", body)

    admission = unmarshal(response.body, Admission)

    #@assert Model.verify(admission, crypto)
    #@assert id == Model.id(admission)

    return admission # A deme file is used to verify 
end


function get_ticket_status(router::Router, ticketid::TicketID)

    tid = bytes2hex(bytes(ticketid))
    response = get(router, "/tickets/$tid")

    status = unmarshal(response.body, TicketStatus)

    return status
end


function enroll_member(router::Router, member::Member)
    
    response = post(router, "/braidchain/members", marshal(member))
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function get_chain_commit(router::Router)

    response = get(router, "/braidchain/commit")
    commit = unmarshal(response.body, Commit{ChainState})

    return commit
end




struct CastGuard
    proposal::Proposal
    ack_proposal::AckInclusion
    vote::Vote
    ack_cast::CastAck # this also would contain a seed
    ack_integrity::Vector{AckConsistency}
end


struct EnrollGuard
    admission::Union{Admission, Nothing}
    enrollee::Union{Member, Nothing}
    ack::Union{AckInclusion, Nothing}
end

EnrollGuard() = EnrollGuard(nothing, nothing, nothing)
EnrollGuard(admission::Admission) = EnrollGuard(admission, nothing, nothing)

mutable struct Voter # mutable because it also needs to deal with storage
    deme::Deme
    signer::Signer
    guard::EnrollGuard
    casts::Vector{CastGuard}
    proposals::Vector{Tuple{Int, Proposal}}
end


Model.id(voter::Voter) = Model.id(voter.signer)

Model.pseudonym(voter::Voter) = pseudonym(voter.signer) # I could drop this method in favour of identity
Model.pseudonym(voter::Voter, g) = pseudonym(voter.signer, g)

Model.isadmitted(voter::Voter) = !isnothing(voter.guard.admission)

Model.hasher(voter::Voter) = hasher(voter.deme)

function Voter(deme::Deme) 
    signer = Model.gen_signer(deme.crypto)
    return Voter(deme, signer, EnrollGuard(), CastGuard[], Tuple{Int, Proposal}[])
end

#router = connect(route, gate, hasher)


function enroll!(voter::Voter, router, ticketid, token) # EnrollGuard 

    if !isadmitted(voter)
        admission = seek_admission(router, id(voter), ticketid, token, hasher(voter))
        #@assert isbinding(admission, voter.deme)
        voter.guard = EnrollGuard(admission)
    end

    enroll!(voter, router)

    return
end


function enroll!(voter::Voter, router) # For continuing from the last place

    @assert isadmitted(voter)
    admission = voter.guard.admission

    commit = get_chain_commit(router)

    #isbinding(commit, voter.deme)
    
    g = generator(commit)

    enrollee = Model.approve(Member(admission, g, pseudonym(voter, g)), voter.signer)

    ack = enroll_member(router, enrollee)
    
    voter.guard = EnrollGuard(admission, enrollee, ack)

    return
end




end
