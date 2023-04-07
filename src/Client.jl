module Client
# Methods to interact with HTTP server

using Infiltrator

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, Hash, AckConsistency, AckInclusion, CastAck, DemeSpec, Signer, TicketStatus, Commit, ChainState, Proposal, BallotBoxState, isbinding
using Base: UUID

using ..Model: id, hasher, pseudonym, isbinding, generator, isadmitted, state, verify, crypto, index, root, commit, isconsistent, istallied, issuer

using HTTP: Router, Request, Response, Handler, HTTP, iserror, StatusError

using JSON3
using Dates
using Setfield


using ..Parser: marshal, unmarshal

using ..Model: base16encode, base16decode

destination(route::Router) = route

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
    deme = unmarshal(response.body, DemeSpec)

    return deme
end


function enlist_ticket(router::Router, ticketid::TicketID, hmac::HMAC; dest = destination(router))

    timestamp = Dates.now()
    ticket_auth_code = Model.auth(ticketid, timestamp, hmac)
    body = marshal((ticketid, timestamp, ticket_auth_code))

    response = post(router, "/tickets", body)

    metadata, salt, reply_auth_code = unmarshal(response.body, Tuple{Vector{UInt8}, Vector{UInt8}, Digest})

    @assert isbinding(metadata, ticketid, salt, reply_auth_code, hmac)

    invite = Invite(Digest(metadata), ticketid, Model.token(ticketid, salt, hmac), hasher(hmac), dest)

    return invite
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


function configure(router::Router, proposal::Proposal)

    commit = get_chain_commit(router)
    spec = get_deme(router)

    # Consistency checks need to done here
    
    proposal = @set proposal.anchor = state(commit)
    proposal = @set proposal.collector = spec.collector

    return proposal
end

configure(router::Router) = proposal -> configure(router, proposal)


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


function get_ballotbox_root(router::Router, uuid::UUID, N::Int)
    
    response = get(router, "/poolingstation/$uuid/votes/$N/root")
    
    ack = unmarshal(response.body, AckConsistency{BallotBoxState})
    
    return ack
end


function get_ballotbox_leaf(router::Router, uuid::UUID, N::Int)

    response = get(router, "/poolingstation/$uuid/votes/$N/leaf")
    
    ack = unmarshal(response.body, AckInclusion{BallotBoxState})

    return ack
end


function get_ballotbox_record(router::Router, uuid::UUID, N::Int)

    response = get(router, "/poolingstation/$uuid/votes/$N/record")
    
    record = unmarshal(response.body, CastRecord)

    return record
end


function get_ballotbox_receipt(router::Router, uuid::UUID, N::Int)

    response = get(router, "/poolingstation/$uuid/votes/$N/receipt")
    
    receipt = unmarshal(response.body, CastReceipt)

    return receipt
end


function get_ballotbox_proposal(router::Router, uuid::UUID)

    response = get(router, "/poolingstation/$uuid/proposal")
    
    proposal = unmarshal(response.body, Proposal)

    return proposal
end


function get_ballotbox_spine(router::Router, uuid::UUID)

    response = get(router, "/poolingstation/$uuid/spine")
    
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

Model.istallied(instance::ProposalInstance) = istallied(instance.commit)

iscast(instance::ProposalInstance) = !isnothing(instance.guard)

Model.isopen(instance::ProposalInstance) = Model.isopen(instance.proposal)
Model.status(instance::ProposalInstance) = Model.status(instance.proposal)

mutable struct DemeAccount # mutable because it also needs to deal with storage
    deme::DemeSpec
    signer::Signer
    guard::EnrollGuard
    #casts::Vector{CastGuard}
    #cache::Vector{Tuple{Int, Proposal}} # 
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
    println(io, "  casts : $(voter.casts)")


    for (i, p) in voter.cache

        println(io, "")
        print(io, "  $i\t")
        print(io, Model.show_string(p))

    end
end



#router = connect(route, gate, hasher)


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


function enroll!(voter::DemeAccount, router) # For continuing from the last place

    @assert isadmitted(voter)
    admission = voter.guard.admission

    update_commit!(voter, router)

    # commit = get_chain_commit(router)
    # @assert isbinding(commit, voter.deme)
    # @assert verify(commit, crypto(voter.deme))

    # voter.commit = commit
    
    g = generator(voter.commit)

    enrollee = Model.approve(Member(admission, g, pseudonym(voter, g)), voter.signer)

    ack = enroll_member(router, enrollee)

    @assert isbinding(enrollee, ack, voter.deme) # 
    @assert verify(enrollee, crypto(voter.deme))
    
    voter.guard = EnrollGuard(admission, enrollee, ack)

    return
end


function update_proposal_cache!(voter::DemeAccount, router)

    proposal_list = get_proposal_list(router)
    
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


function update_deme!(voter::DemeAccount, router)

    update_proposal_cache!(voter, router)
    update_commit!(voter, router)

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




function cast_vote!(instance::ProposalInstance, deme::DemeSpec, selection, signer::Signer; router)

    (; index, proposal) = instance

    ack_leaf = get_chain_leaf(router, index)

    @assert isbinding(proposal, ack_leaf, deme)
    @assert verify(ack_leaf, deme.crypto)
    
    commit = get_ballotbox_commit(router, proposal.uuid)


    @assert isbinding(commit, proposal, hasher(deme))
    @assert verify(commit, Model.crypto(deme))
    
    vote = Model.vote(proposal, Model.seed(commit), selection, signer)
    ack = cast_vote(router, proposal.uuid, vote)

    @assert isbinding(ack, proposal, hasher(deme))
    @assert isbinding(ack, vote, hasher(deme))
    @assert verify(ack, crypto(deme))

    guard = CastGuard(proposal, ack_leaf, vote, ack)
    #push!(voter.casts, guard)
    instance.guard = guard

    return
end


function cast_vote!(voter::DemeAccount, identifier::Union{UUID, Int}, selection)

    instance = get_proposal_instance(voter, identifier)

    #@warn "Imagine a TOR circuit being created..."
    
    cast_vote!(instance, voter.deme, selection, voter.signer; router = voter.route)

    return
end


function cast_guard(voter::DemeAccount, identifier::Union{UUID, Int})

    instance = get_proposal_instance(voter, identifier)

    return instance.guard
end



function check_vote!(instance::ProposalInstance; deme::DemeSpec, router)

    guard = instance.guard
    
    #guard = cast_guard(voter, uuid)
    
    current_commit = commit(guard)

    ack = get_ballotbox_root(router, instance.proposal.uuid, index(current_commit))

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


check_vote!(voter::DemeAccount, uuid::UUID) = check_vote!(get_proposal_instance(voter, uuid); deme = voter.deme, router = voter.route)
check_vote!(voter::DemeAccount, index::Int) = check_vote!(get_proposal_instance(voter, index); deme = voter.deme, router = voter.route)


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
    route # I will need to type this in. IPv4 or IPv6 format?
end


Model.isbinding(spec::DemeSpec, invite::Invite) = Model.digest(spec, invite.hasher) == invite.demehash




function enroll!(router::Router, invite::Invite)
    
    spec = get_deme(router)

    @assert isbinding(spec, invite)

    account = DemeAccount(spec, router)

    enroll!(account, router, invite.ticketid, invite.token)
    
    return account
end


enroll!(invite::Invite) = enroll!(invite.route, invite) # Add a connect method could be useful here



struct DemeClient
    accounts::Vector{DemeAccount}
end


DemeClient() = DemeClient(DemeAccount[])


function enroll!(client::DemeClient, router::Router, invite::Invite)

    account = enroll!(router, invite)
    push!(client.accounts, account)

    return
end


enroll!(client::DemeClient, invite::Invite) = enroll!(client, invite.route, invite)


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

#proposals(client::DemeClient, uuid::UUID) = proposals(select(client, uuid))

cast_vote!(client::DemeClient, uuid::UUID, index::Int, selection) = cast_vote!(select(client, uuid), index, selection)


check_vote!(client::DemeClient, uuid::UUID, index::Int) = check_vote!(select(client, uuid), index)

Model.istallied(client::DemeClient, uuid::UUID, index::Int) = istallied(select(client, uuid), index)

get_ballotbox_commit!(client::DemeClient, uuid::UUID, index::Int) = get_ballotbox_commit!(select(client, uuid), index)






end
