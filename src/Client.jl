module Client
# Methods to interact with HTTP server

using Infiltrator

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, Hash, AckConsistency, AckInclusion, CastAck, Deme, Signer, TicketStatus, Commit, ChainState, Proposal, BallotBoxState
using Base: UUID


using ..Model: id, hasher, pseudonym, isbinding, generator, isadmitted, state, verify, crypto

using HTTP: Router, Request, Response, Handler, HTTP, iserror, StatusError

using JSON3
using Dates
using Setfield


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


function enlist_proposal(router::Router, proposal::Proposal)

    response = post(router, "/braidchain/proposals", marshal(proposal))
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function enlist_proposal(router::Router, proposal::Proposal, guardian::Signer)

    commit = get_chain_commit(router)

    proposal = @set proposal.anchor = state(commit)
    proposal = @set proposal.collector = id(guardian)

    proposal = Model.approve(proposal, guardian)
    
    return proposal, enlist_proposal(router, proposal)    
end


function get_proposal_list(router::Router)

    response = get(router, "/braidchain/proposals")
    
    proposal_list = unmarshal(response.body, Vector{Tuple{Int, Proposal}})

    # Perhaps the list needs to be supplemented with a commit. 
    # Meanwhile the issuer signature can be used to check the integrity
    # An attack vector where issuer is corrupt and issues different proposals for different people is something to be aware of
    # Though it would not go through as the inclusion proof would be asked from the braidchain.

    return proposal_list
end


function get_chain_leaf(router::Router, N::Int)

    response = get(router, "/braidchain/$N/leaf")
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function get_chain_root(router::Router, N::Int)

    response = get(router, "/braidchain/$N/root")
    ack = unmarshal(response.body, AckConsistency{ChainState})

    return ack
end


function get_chain_record(router::Router, N::Int)

    response = get(router, "/braidchain/$N/record")
    
    @show response # Need a way to get a type information
    
    error("Not implemented")
end


function get_ballotbox_commit(router::Router, uuid::UUID)

    response = get(router, "/poolingstation/$uuid/commit")
    
    commit = unmarshal(response.body, Commit{BallotBoxState})
    
    return commit
end

function cast_vote(router::Router, uuid::UUID, vote::Vote)

    response = post(router, "/poolingstation/$(uuid)/votes", marshal(vote))

    ack = unmarshal(response.body, CastAck)

    return ack
end


struct CastGuard
    proposal::Proposal
    ack_proposal::AckInclusion
    vote::Vote
    ack_cast::CastAck # this also would contain a seed
    ack_integrity::Vector{AckConsistency}
end

CastGuard(proposal::Proposal, ack_proposal::AckInclusion, vote::Vote, ack_cast::CastAck) = CastGuard(proposal, ack_proposal, vote, ack_cast, AckConsistency[])

root(guard::CastGuard) = isempty(guard.ack_integrity) ? root(guard.ack_cast) : root(guard.ack_integrity)


struct EnrollGuard
    admission::Union{Admission, Nothing}
    enrollee::Union{Member, Nothing}
    ack::Union{AckInclusion, Nothing}
end

function Base.show(io::IO, guard::EnrollGuard)

    println(io, "EnrollGuard:")

    if !isnothing(guard.enrollee)
        println(io, Model.show_string(guard.enrollee))
        print(io, Model.show_string(guard.ack))
    else
        println(io, Model.show_string(guard.admission))
    end
    
end


EnrollGuard() = EnrollGuard(nothing, nothing, nothing)
EnrollGuard(admission::Admission) = EnrollGuard(admission, nothing, nothing)

mutable struct Voter # mutable because it also needs to deal with storage
    deme::Deme
    signer::Signer
    guard::EnrollGuard
    casts::Vector{CastGuard}
    cache::Vector{Tuple{Int, Proposal}}
end


Model.id(voter::Voter) = Model.id(voter.signer)

Model.pseudonym(voter::Voter) = pseudonym(voter.signer) # I could drop this method in favour of identity
Model.pseudonym(voter::Voter, g) = pseudonym(voter.signer, g)

Model.isadmitted(voter::Voter) = !isnothing(voter.guard.admission)

Model.hasher(voter::Voter) = hasher(voter.deme)

proposals(voter::Voter) = collect(proposal for (index, proposal) in voter.cache)


function Base.show(io::IO, voter::Voter)

    println(io, "Voter:")
    println(io, Model.show_string(voter.deme))
    println(io, Model.show_string(voter.signer))
    println(io, Model.show_string(voter.guard))
    println(io, "  casts : $(voter.casts)")


    for (i, p) in voter.proposals

        println(io, "")
        print(io, "  $i\t")
        print(io, Model.show_string(p))

    end
end



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

    # TODO: Add assertions 

    #isbinding(commit, voter.deme)
    
    g = generator(commit)

    enrollee = Model.approve(Member(admission, g, pseudonym(voter, g)), voter.signer)

    ack = enroll_member(router, enrollee)
    
    voter.guard = EnrollGuard(admission, enrollee, ack)

    return
end


function update_proposal_cache!(voter::Voter, router)

    proposal_list = get_proposal_list(router)
    
    resize!(voter.cache, 0)
    append!(voter.cache, proposal_list)

    return
end


function get_index(voter::Voter, proposal::Proposal)

    for (n, p) in voter.cache

        if p == proposal
            return n
        end
    end

    error("Can't be here. Proposal not found in voter's cache.")
end


function get_record(voter::Voter, uuid::UUID)

    for (index, proposal) in voter.cache

        if proposal.uuid == uuid
            return (index, proposal)
        end
    end

    error("Can't be here. Proposal not found in voter's cache.")
end


function cast_vote!(voter::Voter, router::Router, uuid::UUID, selection)

    index, proposal = get_record(voter, uuid)

    ack_leaf = get_chain_leaf(router, index)

    @assert isbinding(proposal, ack_leaf, voter.deme)
    @assert verify(ack_leaf, voter.deme.crypto)
    
    commit = get_ballotbox_commit(router, proposal.uuid)
    
    @assert isbinding(commit, proposal, hasher(voter.deme))
    @assert verify(commit, Model.crypto(voter.deme))
    
    vote = Model.vote(proposal, Model.seed(commit), selection, voter.signer)
    ack = cast_vote(router, proposal.uuid, vote)

    @assert isbinding(ack, proposal, hasher(voter.deme))
    @assert isbinding(ack, vote, hasher(voter.deme))
    @assert verify(ack, crypto(voter.deme))

    guard = CastGuard(proposal, ack_leaf, vote, ack)
    push!(voter.casts, guard)

    return
end



end
