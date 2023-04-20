module Client
# Methods to interact with HTTP server

using Infiltrator

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, Hash, AckConsistency, AckInclusion, CastAck, DemeSpec, Signer, TicketStatus, Commit, ChainState, Proposal, BallotBoxState, isbinding, isopen
using Base: UUID

using ..Model: id, hasher, pseudonym, isbinding, generator, isadmitted, state, verify, crypto, index, root, commit, isconsistent, istallied, issuer

using HTTP: Router, Request, Response, Handler, HTTP, iserror, StatusError

using JSON3
using Dates
using Setfield

import StructTypes
using StructHelpers

using ..Parser: marshal, unmarshal

using ..Model: base16encode, base16decode


using URIs: URI

abstract type Route end

struct LocalRoute <: Route
    router::Router
end

(server::LocalRoute)(req::Request)::Response = server.router(req)

destination(route::LocalRoute) = URI()

struct RemoteRoute <: Route
    url::URI
end


(server::RemoteRoute)(req::Request)::Response = HTTP.request(req.method, URI(server.url; path = req.target), req.headers, req.body)

destination(route::RemoteRoute) = route.url

struct OnionRoute <: Route
    url::URI
    # circuit
end


route(str::String) = route(URI(str))
route(url::URI) = url == URI() ? error("Empty url not allowed") : RemoteRoute(url)
route(router::Router) = LocalRoute(router)


function request(server::Route, method::String, target::String, body::Vector{UInt8})::Response

    request = Request(method, target, [], body)
    response = server(request) # seens natural that it is callable as function

    iserror(response) && throw(StatusError(response.status, method, target, response))

    return response
end

post(server::Route, target, body)::Response = request(server, "POST", target, body)
put(server::Route, target, body)::Response = request(server, "PUT", target, body)
get(server::Route, target)::Response = request(server, "GET", target, UInt8[])


function get_deme(server::Route)

    response = get(server, "/deme")
    deme = unmarshal(response.body, DemeSpec)

    return deme
end


function enlist_ticket(server::Route, ticketid::TicketID, hmac::HMAC; dest = destination(server))

    timestamp = Dates.now()
    ticket_auth_code = Model.auth(ticketid, timestamp, hmac)
    body = marshal((ticketid, timestamp, ticket_auth_code))

    response = post(server, "/tickets", body)

    metadata, salt, reply_auth_code = unmarshal(response.body, Tuple{Vector{UInt8}, Vector{UInt8}, Digest})

    @assert isbinding(metadata, ticketid, salt, reply_auth_code, hmac)

    if salt == UInt8[]
        error("TicketID with $(bytes2hex(ticketid))is already admitted.")
    end

    invite = Invite(Digest(metadata), ticketid, Model.token(ticketid, salt, hmac), hasher(hmac), dest)

    return invite
end


function seek_admission(server::Route, id::Pseudonym, ticketid::TicketID, token::Digest, hasher::Hash)

    auth_code = Model.auth(id, token, hasher)
    body = marshal((id, auth_code))
    tid = bytes2hex(bytes(ticketid))
    response = put(server, "/tickets/$tid", body)

    admission = unmarshal(response.body, Admission)

    #@assert Model.verify(admission, crypto)
    #@assert id == Model.id(admission)

    return admission # A deme file is used to verify 
end


function get_ticket_status(server::Route, ticketid::TicketID)

    tid = bytes2hex(bytes(ticketid))
    response = get(server, "/tickets/$tid")

    status = unmarshal(response.body, TicketStatus)

    return status
end


function enroll_member(server::Route, member::Member)
    
    response = post(server, "/braidchain/members", marshal(member))
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function get_chain_commit(server::Route)

    response = get(server, "/braidchain/commit")
    commit = unmarshal(response.body, Commit{ChainState})

    return commit
end


function enlist_proposal(server::Route, proposal::Proposal)

    response = post(server, "/braidchain/proposals", marshal(proposal))
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function configure(server::Route, proposal::Proposal)

    commit = get_chain_commit(server)
    spec = get_deme(server)

    # Consistency checks need to done here
    
    proposal = @set proposal.anchor = state(commit)
    proposal = @set proposal.collector = spec.collector

    return proposal
end


configure(server::Route) = proposal -> configure(server, proposal)


function get_proposal_list(server::Route)

    response = get(server, "/braidchain/proposals")
    
    proposal_list = unmarshal(response.body, Vector{Tuple{Int, Proposal}})

    # Perhaps the list needs to be supplemented with a commit. 
    # Meanwhile the issuer signature can be used to check the integrity
    # An attack vector where issuer is corrupt and issues different proposals for different people is something to be aware of
    # Though it would not go through as the inclusion proof would be asked from the braidchain.

    return proposal_list
end


function get_chain_leaf(server::Route, N::Int)

    response = get(server, "/braidchain/$N/leaf")
    ack = unmarshal(response.body, AckInclusion{ChainState})

    return ack
end


function get_chain_root(server::Route, N::Int)

    response = get(server, "/braidchain/$N/root")
    ack = unmarshal(response.body, AckConsistency{ChainState})

    return ack
end


function get_chain_record(server::Route, N::Int)

    response = get(server, "/braidchain/$N/record")
    
    @show response # Need a way to get a type information
    
    error("Not implemented")
end


function get_ballotbox_commit(server::Route, uuid::UUID)

    response = get(server, "/poolingstation/$uuid/commit")
    
    commit = unmarshal(response.body, Commit{BallotBoxState})
    
    return commit
end


function cast_vote(server::Route, uuid::UUID, vote::Vote)

    response = post(server, "/poolingstation/$(uuid)/votes", marshal(vote))

    ack = unmarshal(response.body, CastAck)

    return ack
end


function get_ballotbox_root(server::Route, uuid::UUID, N::Int)
    
    response = get(server, "/poolingstation/$uuid/votes/$N/root")
    
    ack = unmarshal(response.body, AckConsistency{BallotBoxState})
    
    return ack
end


function get_ballotbox_leaf(server::Route, uuid::UUID, N::Int)

    response = get(server, "/poolingstation/$uuid/votes/$N/leaf")
    
    ack = unmarshal(response.body, AckInclusion{BallotBoxState})

    return ack
end


function get_ballotbox_record(server::Route, uuid::UUID, N::Int)

    response = get(server, "/poolingstation/$uuid/votes/$N/record")
    
    record = unmarshal(response.body, CastRecord)

    return record
end


function get_ballotbox_receipt(server::Route, uuid::UUID, N::Int)

    response = get(server, "/poolingstation/$uuid/votes/$N/receipt")
    
    receipt = unmarshal(response.body, CastReceipt)

    return receipt
end


function get_ballotbox_proposal(server::Route, uuid::UUID)

    response = get(server, "/poolingstation/$uuid/proposal")
    
    proposal = unmarshal(response.body, Proposal)

    return proposal
end


function get_ballotbox_spine(server::Route, uuid::UUID)

    response = get(server, "/poolingstation/$uuid/spine")
    
    spine = unmarshal(response.body, Vector{Digest})

    return spine
end


struct Blame
    commit::Commit{BallotBoxState}
    ack::AckConsistency{BallotBoxState}
end


Model.issuer(blame::Blame) = issuer(blame.commit)


function Model.verify(blame::Blame, crypto)

    (; commit, ack) = blame
    
    isbinding(commit, ack) || return false

    !isconsistent(commit, ack) || return false # if there is anything to blame on

    verify(commit, crypto) || return false
    verify(ack, crypto) || return false

    return true
end


function Model.isbinding(blame::Blame, proposal::Proposal, hasher::Hash)
    
    blame.commit.state.proposal == Model.digest(proposal, hasher) || return false
    issuer(blame) == proposal.collector || return false

    return true
end


struct CastGuard
    proposal::Proposal
    ack_proposal::AckInclusion{ChainState}
    vote::Vote
    ack_cast::CastAck # this also would contain a seed
    ack_integrity::Vector{AckConsistency{BallotBoxState}}
    blame::Vector{Blame}
end

CastGuard(proposal::Proposal, ack_proposal::AckInclusion, vote::Vote, ack_cast::CastAck) = CastGuard(proposal, ack_proposal, vote, ack_cast, AckConsistency[], Blame[])

Model.commit(guard::CastGuard) = isempty(guard.ack_integrity) ? commit(guard.ack_cast) : commit(guard.ack_integrity[end])

Model.index(guard::CastGuard) = index(guard.ack_cast)


Model.isbinding(guard::CastGuard, ack::AckConsistency{BallotBoxState}) = isbinding(commit(guard), ack)
Model.isconsistent(guard::CastGuard, ack::AckConsistency{BallotBoxState}) = isconsistent(commit(guard), ack)


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


mutable struct ProposalInstance # ProposalArea, BallotBoxClient?
    const index::Int
    const proposal::Proposal
    commit::Union{Nothing, Commit{BallotBoxState}}
    guard::Union{Nothing, CastGuard} 
end

ProposalInstance(index::Int, proposal::Proposal) = ProposalInstance(index, proposal, nothing, nothing)

#Model.istallied(instance::ProposalInstance) = isnothing(instance.commit) ? false : istallied(instance.commit)

Model.istallied(instance::ProposalInstance) = isnothing(Model.commit(instance)) ? false : istallied(Model.commit(instance)) # This is where pattern matching would be useful to have

iscast(instance::ProposalInstance) = !isnothing(instance.guard)

Model.isopen(instance::ProposalInstance) = Model.isopen(instance.proposal; time = Dates.now())
Model.status(instance::ProposalInstance) = Model.status(instance.proposal)


# This logic would be unnecessary if commit would only be available in the guard
function Model.commit(instance::ProposalInstance)
    
    _commit_instance = instance.commit
    _commit_guard = isnothing(instance.guard) ? nothing : commit(instance.guard)

    if !isnothing(_commit_instance) && !isnothing(_commit_guard)

        if _commit_instance.state.index > _commit_guard.state.index

            return _commit_instance

        elseif _commit_instance.state.index == _commit_guard.state.index

            if !isnothing(_commit_instance.state.tally)
                return _commit_instance
            else
                return _commit_guard
            end

        else
            return _commit_guard
        end

    elseif !isnothing(_commit_instance)

        return _commit_instance

    elseif !isnothing(_commit_guard)

        return _commit_guard

    else

        return nothing

    end

end


mutable struct DemeAccount # mutable because it also needs to deal with storage
    deme::DemeSpec
    signer::Signer
    guard::EnrollGuard
    proposals::Vector{ProposalInstance}
    commit::Union{Commit{ChainState}, Nothing}
    route # 
end

function DemeAccount(deme::DemeSpec, route = nothing) 
    signer = Model.generate(Signer, crypto(deme))
    return DemeAccount(deme, signer, EnrollGuard(), ProposalInstance[], nothing, route)
end


Model.id(voter::DemeAccount) = Model.id(voter.signer)

Model.pseudonym(voter::DemeAccount) = pseudonym(voter.signer) # I could drop this method in favour of identity
Model.pseudonym(voter::DemeAccount, g) = pseudonym(voter.signer, g)
Model.pseudonym(voter::DemeAccount, proposal::Proposal) = pseudonym(voter.signer, Model.generator(proposal))
Model.pseudonym(voter::DemeAccount, instance::ProposalInstance) = pseudonym(voter, instance.proposal)

Model.isadmitted(voter::DemeAccount) = !isnothing(voter.guard.admission)

Model.hasher(voter::DemeAccount) = hasher(voter.deme)


function get_ballotbox_commit!(account::DemeAccount, identifier::Union{UUID, Int})

    instance = get_proposal_instance(account, identifier)

    commit = get_ballotbox_commit(account.route, instance.proposal.uuid)
    
    @assert isbinding(commit, instance.proposal, hasher(account.deme))
    @assert verify(commit, crypto(account.deme))

    instance.commit = commit

    return
end


function get_proposal(account::DemeAccount, index::Int)

    for (i, p) in proposals(account)
        if i == index
            return p
        end
    end

    error("Proposal with index $index not found")
end


function Base.show(io::IO, voter::DemeAccount)

    println(io, "Voter:")
    println(io, Model.show_string(voter.deme))
    println(io, Model.show_string(voter.signer))
    println(io, Model.show_string(voter.guard))
    #println(io, "  casts : $(voter.casts)")


    for instance in voter.proposals

        println(io, "")
        print(io, "  $(instance.index)\t")
        print(io, Model.show_string(instance.proposal))

    end
end


function enroll!(voter::DemeAccount, router, ticketid, token) # EnrollGuard 

    if !isadmitted(voter)
        admission = seek_admission(router, id(voter), ticketid, token, hasher(voter))
        @assert isbinding(admission, voter.deme) # checks the guardian
        @assert verify(admission, crypto(voter.deme))
        voter.guard = EnrollGuard(admission)
    end

    enroll!(voter, router)

    return
end


function update_commit!(voter::DemeAccount, router)

    commit = get_chain_commit(router)

    @assert isbinding(commit, voter.deme)
    @assert verify(commit, crypto(voter.deme))
    
    voter.commit = commit
    
    return
end

update_commit!(voter::DemeAccount) = update_commit!(voter, voter.route)


function enroll!(voter::DemeAccount, route::Route) # For continuing from the last place

    @assert isadmitted(voter)
    admission = voter.guard.admission

    update_commit!(voter, route)

    # commit = get_chain_commit(router)
    # @assert isbinding(commit, voter.deme)
    # @assert verify(commit, crypto(voter.deme))

    # voter.commit = commit
    
    g = generator(voter.commit)

    enrollee = Model.approve(Member(admission, g, pseudonym(voter, g)), voter.signer)

    ack = enroll_member(route, enrollee)

    @assert isbinding(enrollee, ack, voter.deme) # 
    @assert verify(enrollee, crypto(voter.deme))
    
    voter.guard = EnrollGuard(admission, enrollee, ack)

    return
end


function update_proposal_cache!(voter::DemeAccount, route::Route)

    proposal_list = get_proposal_list(route)
    
    for (index, proposal) in proposal_list

        location = findfirst(instance -> instance.index == index, voter.proposals)

        if isnothing(location)

            push!(voter.proposals, ProposalInstance(index, proposal))

        else

            @assert voter.proposals[location].proposal == proposal "Invalid local cache for proposal. Something have gone horibly wrong..."
        end


    end

    return
end

update_proposal_cache!(voter::DemeAccount) = update_proposal_cache!(voter, voter.route)


function update_deme!(voter::DemeAccount, route::Route)

    update_proposal_cache!(voter, route)
    update_commit!(voter, route)

    return
end

update_deme!(voter::DemeAccount) = update_deme!(voter, voter.route)


function get_index(voter::DemeAccount, proposal::Proposal)

    for (n, p) in voter.cache

        if p == proposal
            return n
        end
    end

    error("Can't be here. Proposal not found in voter's cache.")
end


function get_proposal_instance(voter::DemeAccount, uuid::UUID)

    for instance in voter.proposals

        if instance.proposal.uuid == uuid
            return instance
        end
    end

    error("Can't be here. Proposal not found in voter's cache.")
end


function get_proposal_instance(voter::DemeAccount, index::Int)

    for instance in voter.proposals

        if instance.index == index
            return instance
        end
    end

    error("Can't be here. Proposal not found in voter's cache.")
end


list_proposal_instances(voter::DemeAccount) = voter.proposals

using Infiltrator

function cast_vote!(instance::ProposalInstance, deme::DemeSpec, selection, signer::Signer; server::Route)

    (; index, proposal) = instance

    ack_leaf = get_chain_leaf(server, index)

    #@infiltrate
    @assert isbinding(proposal, ack_leaf, deme)
    @assert verify(ack_leaf, deme.crypto)
    
    commit = get_ballotbox_commit(server, proposal.uuid)


    @assert isbinding(commit, proposal, hasher(deme))
    @assert verify(commit, Model.crypto(deme))
    
    vote = Model.vote(proposal, Model.seed(commit), selection, signer)
    ack = cast_vote(server, proposal.uuid, vote)

    @assert isbinding(ack, proposal, hasher(deme))
    @assert isbinding(ack, vote, hasher(deme))
    @assert verify(ack, crypto(deme))

    guard = CastGuard(proposal, ack_leaf, vote, ack)
    instance.guard = guard

    return
end


function cast_vote!(voter::DemeAccount, identifier::Union{UUID, Int}, selection)

    instance = get_proposal_instance(voter, identifier)

    #@warn "Imagine a TOR circuit being created..."
    
    cast_vote!(instance, voter.deme, selection, voter.signer; server = voter.route)

    return
end


function cast_guard(voter::DemeAccount, identifier::Union{UUID, Int})

    instance = get_proposal_instance(voter, identifier)

    return instance.guard
end



function check_vote!(instance::ProposalInstance; deme::DemeSpec, server::Route)

    guard = instance.guard
    
    current_commit = commit(guard)

    ack = get_ballotbox_root(server, instance.proposal.uuid, index(current_commit))

    @assert isbinding(ack, current_commit) "Received acknowledgment is not binding to request."
    
    @assert verify(ack, crypto(deme)) "Received acknowledgemnt is not genuine."

    if isconsistent(ack, current_commit)
        push!(guard.ack_integrity, ack)
    else
        blame = Blame(current_commit, ack)
        push!(guard.blame, blame)
        error("The integrity for the record of votes in the ballot box has been compromised. This occurs when the person collecting the ballots acts with bad intent, or if the key have been stolen. This undisputable evidence is recorded in the guard and is available as `blame(voter, uuid)` which should be delivered to observers, who will take action to resolve misconduct of the collector.")
    end
    
    if istallied(state(ack))
        @assert state(ack).view[index(guard)] == true "Your vote have not been included in the final tally. This may be because your unique key used to submit the vote has been exposed and someone else has used it to revote afterwards. To resolve this issue, you should reach out to the guardian and ask for new credentials, and also reconsider whether your device can be trusted."
    end
    
    return 
end


check_vote!(voter::DemeAccount, uuid::UUID) = check_vote!(get_proposal_instance(voter, uuid); deme = voter.deme, server = voter.route)
check_vote!(voter::DemeAccount, index::Int) = check_vote!(get_proposal_instance(voter, index); deme = voter.deme, server = voter.route)


function Model.istallied(voter::DemeAccount, identifier::Union{UUID, Int})

    instance = get_proposal_instance(voter, identifier)

    return istallied(instance)
end


function blame(voter::DemeAccount, uuid::UUID)
    
    guard = cast_guard(voter, uuid)

    if isempty(guard.blame)
        return nothing
    else
        return guard.blame[end]
    end
end


struct Invite
    demehash::Digest
    ticketid::TicketID
    token::Digest
    hasher::Hash # HashSpec
    #route # I will need to type this in. IPv4 or IPv6 format?
    route::URI
end

@batteries Invite

Model.isbinding(spec::DemeSpec, invite::Invite) = Model.digest(spec, invite.hasher) == invite.demehash

# Parsing to string and back
StructTypes.StructType(::Type{Invite}) = StructTypes.CustomStruct()

StructTypes.lower(invite::Invite) = Dict(:demehash => invite.demehash, :ticketid => invite.ticketid, :token => invite.token, :hasher => invite.hasher, :route => string(invite.route))

function StructTypes.construct(::Type{Invite}, data::Dict)

    demehash = StructTypes.constructfrom(Digest, data["demehash"])
    ticketid = StructTypes.constructfrom(TicketID, data["ticketid"])
    token = StructTypes.constructfrom(Digest, data["token"])
    hasher = StructTypes.constructfrom(Hash, data["hasher"])
    route = URI(data["route"])
    
    return Invite(demehash, ticketid, token, hasher, route)
end


# Parser.marshal, Parser.unmarshal ; Client.enroll method seems like a good fit where to do parsing 


function enroll!(invite::Invite; server::Route = route(invite.route))
    
    spec = get_deme(server)

    @assert isbinding(spec, invite)

    account = DemeAccount(spec, server)

    enroll!(account, server, invite.ticketid, invite.token)
    
    return account
end


struct DemeClient
    accounts::Vector{DemeAccount}
end


DemeClient() = DemeClient(DemeAccount[])


function enroll!(client::DemeClient, invite::Invite; server::Route = route(invite.route)) #; server::Route = route(invite.route))

    account = enroll!(invite; server)
    push!(client.accounts, account)

    return account
end


function select(client::DemeClient, uuid::UUID)

    for a in client.accounts

        if a.deme.uuid == uuid
            return a
        end

    end

    error("No deme with $uuid found")

end


update_deme!(client::DemeClient, uuid::UUID) = update_deme!(select(client, uuid))

list_proposal_instances(client::DemeClient, uuid::UUID) = list_proposal_instances(select(client, uuid))

cast_vote!(client::DemeClient, uuid::UUID, index::Int, selection) = cast_vote!(select(client, uuid), index, selection)

check_vote!(client::DemeClient, uuid::UUID, index::Int) = check_vote!(select(client, uuid), index)

Model.istallied(client::DemeClient, uuid::UUID, index::Int) = istallied(select(client, uuid), index)

get_ballotbox_commit!(client::DemeClient, uuid::UUID, index::Int) = get_ballotbox_commit!(select(client, uuid), index)


reset!(client::DemeClient) = empty!(client.accounts)

end
