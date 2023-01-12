module Client
# Methods to interact with HTTP server

using Infiltrator

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, Hash, AckConsistency, AckInclusion, CastAck, Deme, Signer
using HTTP: Router, Request, Response, Handler, HTTP, iserror

using JSON3
using Dates


using ..Parser: marshal, unmarshal

using ..Model: base16encode, base16decode


# A server client method for submitting a new ticket and receiving a token

# hex2bytes 
# bytes2hex

post(route::String, target::String, body) = HTTP.post(route * target, body)
put(route::String, target::String, body) = HTTP.put(route * target, body)


function request(method::String, router::Router, target::String, body::Vector{UInt8})

    request = Request("POST", target, [], body)
    response = router(request)

    return response
end


request(method::String, route::String, target::String, body::Vector{UInt8}) = HTTP.request(method, route * target, body)


post(route, target, body) = request("POST", route, target, body)
put(route, target, body) = request("PUT", route, target, body)
get(route, target) = request("GET", route, target, body)




function enlist_ticket(router::Router, ticketid::TicketID, hmac::HMAC)

    timestamp = Dates.now()
    ticket_auth_code = Model.auth(ticketid, timestamp, hmac)
    body = marshal((ticketid, timestamp, ticket_auth_code))

    response = post(router, "/tickets", body)

    @assert !iserror(response)

    salt, salt_auth_code = unmarshal(response.body, Tuple{Vector{UInt8}, Digest})

    @assert isbinding(ticketid, salt, salt_auth_code, hmac)

    return Model.token(ticketid, salt, hmac)
end



function seek_admission(router::Router, id::Pseudonym, ticketid::TicketID, token::Digest, hasher::Hash)

    auth_code = Model.auth(id, token, hasher)
    body = marshal((id, auth_code))
    tid = bytes2hex(bytes(ticketid))
    response = put(router, "/tickets/$tid", body)

    @assert !iserror(response)

    admission = unmarshal(response.body, Admission)

    #@assert Model.verify(admission, crypto)
    #@assert id == Model.id(admission)

    return admission # A deme file is used to verify 
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

mutable struct Voter # mutable because it also needs to deal with storage
    deme::Deme
    signer::Signer
    guard::EnrollGuard
    casts::Vector{CastGuard}
    proposals::Vector{Tuple{Int, Proposal}}
end


Model.id(voter::Voter) = Model.id(voter.signer)


function Voter(deme::Deme) 
    signer = Model.gen_signer(deme.crypto)
    return Voter(deme, signer, EnrollGuard(), CastGuard[], Tuple{Int, Proposal}[])
end

#router = connect(route, gate, hasher)


function enroll!(voter::Voter, router, ticketid, token) # EnrollGuard 
    # checks that 
end


function enroll!(voter::Voter, router) # For continuing from the last place
    # something else
end




end
