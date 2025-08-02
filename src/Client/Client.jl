module Client
# Methods to interact with HTTP server

using Base: UUID
using URIs: URI
using HTTP: Router, Request, Response, Handler, HTTP, iserror, StatusError

using Dates
using Setfield

import StructTypes

using ..Core.Model: Model, Membership, Pseudonym, Proposal, Generator, Vote, bytes, TicketID, HMAC, Admission, isbinding, verify, Digest, HashSpec, DemeSpec, Signer,  Commit, ChainState, Proposal, BallotBoxState, isbinding, isopen, digest, commit
using ..Core.Model: id, hasher, pseudonym, generator, state, verify, crypto, index, root, isconsistent, istallied, issuer, termination_bitmask
using ..Core.ProtocolSchema: ProtocolSchema, TicketStatus, tokenid, Invite, AckConsistency, AckInclusion, CastAck
using ..Core.Parser: marshal, unmarshal
using ..Core.Store: Store
using ..Authorization: AuthClientMiddleware
using ..TempAccessCodes: TempAccessCodes # Needed for track_vote. 
using ..Base32: encode_crockford_base32, decode_crockford_base32

using HistoryTrees: ConsistencyProof

import ..Core.Model


struct DummyStore end
store!(::DummyStore, args...) = nothing
Base.joinpath(store::DummyStore, index::Int) = store

struct AccountStore 
    base::String
    key::String
end

function AccountStore(dir::String, uuid::UUID, token::Vector{UInt8})
    account_name = join([string(uuid), bytes2hex(token)], ":")
    return AccountStore(joinpath(dir, "accounts", account_name), joinpath(dir, "keys", account_name))
end

#AccountStore(dir::String) = AccountStore(dir, joinpath(dir, "keys"))

struct ProposalStore
    account::AccountStore # temporary
    dir::String
end

function Base.joinpath(store::AccountStore, index::Int)

    index_string(i::Int) = bytes2hex(reinterpret(UInt8, [i])[1:2] |> reverse)

    dir = joinpath(store.base, "proposals", index_string(index))
    return ProposalStore(store, dir)
end


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

Route(x) = route(x) # For simplicity

function request(server::Route, method::String, target::String, body::Vector{UInt8})::Response

    request = Request(method, target, [], body)
    response = server(request) # seens natural that it is callable as function

    iserror(response) && throw(StatusError(response.status, method, target, response))

    return response
end

post(server::Route, target, body)::Response = request(server, "POST", target, body)
put(server::Route, target, body)::Response = request(server, "PUT", target, body)
get(server::Route, target)::Response = request(server, "GET", target, UInt8[])
get(args...) = Base.get(args...) # This way previous method  would not be registerd

function get_deme(server::Route)

    response = get(server, "/deme")
    deme = unmarshal(response.body, DemeSpec)

    return deme
end


function seek_admission(server::Route, id::Pseudonym, invite::Invite)

    body = marshal(id)
    _tokenid = tokenid(invite.token, hasher(invite))

    request = Request("PUT", "/tickets", ["Host" => invite.route.host], body)
    
    response = request |> AuthClientMiddleware(server, _tokenid, invite.token)

    if response.status == 200

        admission = unmarshal(response.body, Admission)

        #@assert Model.verify(admission, crypto)
        #@assert id == Model.id(admission)

        return admission # A deme file is used to verify 
    else
        error("Request failure $(response.status): $(String(response.body))")
    end
end


function get_ticket_status(server::Route, ticketid::TicketID)

    tid = bytes2hex(bytes(ticketid))
    response = get(server, "/tickets/$tid")

    status = unmarshal(response.body, TicketStatus)

    return status
end


function enroll_member(server::Route, member::Membership)
    
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
    record_type = Dict(response.headers)["X-Record-Type"]

    if record_type == "DemeSpec"
        return unmarshal(response.body, DemeSpec)
    elseif record_type == "Membership"
        return unmarshal(response.body, Membership)
    elseif record_type == "Proposal"
        return unmarshal(response.body, Proposal)
    elseif record_type == "BraidReceipt"
        return Store.load(Model.BraidReceipt, response.body)
    else
        error("Record type $record_type not recognized")
    end
        
    return
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

# A better schema could be considered
# perhaps naming: first, last, connection|binding
# struct Blame
#     commitA::Commit{BallotBoxState}
#     commitB::Commit{BallotBoxState}
#     proof::ConsitencyProof
# end

Model.issuer(blame::Blame) = issuer(blame.commit)


function Model.verify(blame::Blame, crypto)

    (; commit, ack) = blame
    
    isbinding(commit, ack) || return false

    !isconsistent(commit, ack) || return false # if there is anything to blame on

    verify(commit, crypto) || return false
    verify(ack, crypto) || return false

    return true
end


function Model.isbinding(blame::Blame, proposal::Proposal, hasher::HashSpec)
    
    blame.commit.state.proposal == Model.digest(proposal, hasher) || return false
    issuer(blame) == proposal.collector || return false

    return true
end


struct CastGuard
    proposal::Proposal
    #ack_proposal::AckInclusion{ChainState}
    vote::Vote
    ack_cast::CastAck # this also would contain a seed
    ack_integrity::Vector{AckConsistency{BallotBoxState}}
    blame::Vector{Blame}
end

CastGuard(proposal::Proposal, vote::Vote, ack_cast::CastAck) = CastGuard(proposal, vote, ack_cast, AckConsistency[], Blame[])

Model.commit(guard::CastGuard) = isempty(guard.ack_integrity) ? commit(guard.ack_cast) : commit(guard.ack_integrity[end])

Model.index(guard::CastGuard) = index(guard.ack_cast)

Model.isbinding(guard::CastGuard, ack::AckConsistency{BallotBoxState}) = isbinding(commit(guard), ack)
Model.isconsistent(guard::CastGuard, ack::AckConsistency{BallotBoxState}) = isconsistent(commit(guard), ack)

tracking_code(guard::CastGuard, spec::DemeSpec) = ProtocolSchema.tracking_code(guard.vote, spec) |> encode_crockford_base32

struct EnrollGuard
    admission::Union{Admission, Nothing}
    enrollee::Union{Membership, Nothing}
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

Model.index(guard::EnrollGuard) = index(guard.ack)

mutable struct ProposalInstance # ProposalArea, BallotBoxClient?
    const index::Int # redundant
    const proposal::Proposal
    const ack_leaf::AckInclusion{ChainState}
    commit::Union{Nothing, Commit{BallotBoxState}}
    guard::Union{Nothing, CastGuard} 
    seq::Int
    store::Union{DummyStore, ProposalStore}
end

ProposalInstance(index::Int, proposal::Proposal, ack_leaf::AckInclusion{ChainState}; store = DummyStore()) = ProposalInstance(index, proposal, ack_leaf, nothing, nothing, 1, store)

#Model.istallied(instance::ProposalInstance) = isnothing(instance.commit) ? false : istallied(instance.commit)

Model.istallied(instance::ProposalInstance) = isnothing(Model.commit(instance)) ? false : istallied(Model.commit(instance)) # This is where pattern matching would be useful to have

iscast(instance::ProposalInstance) = !isnothing(instance.guard)

Model.isopen(instance::ProposalInstance) = Model.isopen(instance.proposal; time = Dates.now(UTC))
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
    route::Route
    store::Union{DummyStore, AccountStore}
end

DemeAccount(deme::DemeSpec, signer::Signer, route = nothing; store = DummyStore()) = DemeAccount(deme, signer, EnrollGuard(), ProposalInstance[], nothing, route, store)


function DemeAccount(deme::DemeSpec, route = nothing; store = DummyStore()) 
    signer = Model.generate(Signer, crypto(deme))
    return DemeAccount(deme, signer, route; store)
end

function DemeAccount(deme::DemeSpec, key::Integer, route = nothing; store = DummyStore())
    signer = Signer(crypto(deme), key)
    return DemeAccount(deme, signer, route; store)
end


Model.id(voter::DemeAccount) = Model.id(voter.signer)
Model.index(voter::DemeAccount) = index(voter.guard)

Model.pseudonym(voter::DemeAccount) = pseudonym(voter.signer) # I could drop this method in favour of identity
Model.pseudonym(voter::DemeAccount, g::Generator) = pseudonym(voter.signer, g)
Model.pseudonym(voter::DemeAccount, proposal::Proposal) = pseudonym(voter.signer, Model.generator(proposal))
Model.pseudonym(voter::DemeAccount, instance::ProposalInstance) = pseudonym(voter, instance.proposal)

#Model.isadmitted(voter::DemeAccount) = !isnothing(voter.guard.admission)

isadmitted(voter::DemeAccount) = !isnothing(voter.guard.admission)

Model.hasher(voter::DemeAccount) = hasher(voter.deme)

iseligiable(voter::DemeAccount) = termination_bitmask(voter.commit)[index(voter)] == false

function get_ballotbox_commit!(account::DemeAccount, identifier::Union{UUID, Int})

    instance = get_proposal_instance(account, identifier)

    commit = get_ballotbox_commit(account.route, instance.proposal.uuid)
    
    @assert isbinding(commit, instance.proposal, hasher(account.deme))
    @assert verify(commit, crypto(account.deme))

    instance.commit = commit
    store!(instance.store, commit)

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

iseligiable(account::DemeAccount, proposal::Proposal) = termination_bitmask(proposal.anchor)[index(account)] == false && index(proposal) > index(account)

function iseligiable(account::DemeAccount, index::Int)
    proposal = get_proposal(account, index)
    return iseligiable(account, proposal)
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


function enroll!(voter::DemeAccount, router, invite::Invite; skip_registration = false) # EnrollGuard 

    if !isadmitted(voter)
        admission = seek_admission(router, id(voter), invite) # Store
        @assert isbinding(admission, voter.deme) # checks the guardian
        @assert verify(admission, crypto(voter.deme))
        voter.guard = EnrollGuard(admission) 
        store!(voter.store, admission)
    end

    skip_registration || enroll!(voter, router)

    return
end


function update_commit!(voter::DemeAccount, router)

    commit = get_chain_commit(router)

    @assert isbinding(commit, voter.deme)
    @assert verify(commit, crypto(voter.deme))

    store!(voter.store, commit)
    
    voter.commit = commit
    
    return
end

update_commit!(voter::DemeAccount) = update_commit!(voter, voter.route)


function enroll!(voter::DemeAccount, route::Route) # For continuing from the last place

    @assert isadmitted(voter)
    admission = voter.guard.admission

    update_commit!(voter, route) # Store

    # commit = get_chain_commit(router)
    # @assert isbinding(commit, voter.deme)
    # @assert verify(commit, crypto(voter.deme))
    
    g = generator(voter.commit)

    # A new cerificate is can be generated only for a new generator
    # Old certeficates need to be stored in case an acknowledgement reply can not reach the client
    # Acknowldgment is sent for this or previously attempted certificates
    enrollee = Model.approve(Membership(admission, g, pseudonym(voter, g)), voter.signer) # Store
    store!(voter.store, enrollee) 

    ack = enroll_member(route, enrollee)

    @assert isbinding(enrollee, ack, voter.deme) # 
    @assert verify(enrollee, crypto(voter.deme))
    
    voter.guard = EnrollGuard(admission, enrollee, ack)
    store!(voter.store, ack)

    return
end


function update_proposal_cache!(voter::DemeAccount, route::Route)

    proposal_list = get_proposal_list(route)

    for (index, proposal) in proposal_list

        location = findfirst(instance -> instance.index == index, voter.proposals)
        
        if isnothing(location)

            # In future ack_leafs would be retrieved together with proposal_list
            # as asking them seperatelly gives away local state to the server
            ack_leaf = get_chain_leaf(route, index)

            @assert ack_leaf.proof.index == index
            @assert isbinding(proposal, ack_leaf, voter.deme)
            @assert verify(ack_leaf, voter.deme.crypto)

            voter.commit = ack_leaf.commit

            instance = ProposalInstance(index, proposal, ack_leaf; store = joinpath(voter.store, index))
            push!(voter.proposals, instance)
            store!(instance.store, proposal)
            store!(instance.store, ack_leaf)

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


function cast_vote!(instance::ProposalInstance, deme::DemeSpec, selection, signer::Signer; server::Route, force = false, seq = nothing)

    (; index, proposal) = instance
    seq = isnothing(seq) ? instance.seq : seq

    # Checking the vote selection before proceeding with the vote
    force || @assert isconsistent(selection, proposal.ballot)
    
    commit = get_ballotbox_commit(server, proposal.uuid)

    @assert isbinding(commit, proposal, hasher(deme))
    @assert verify(commit, Model.crypto(deme))

    instance.seq += 1 
    vote = Model.vote(proposal, Model.seed(commit), selection, signer; force = true, seq)
    store!(instance.store, vote)

    ack = cast_vote(server, proposal.uuid, vote)

    @assert isbinding(ack, proposal, hasher(deme))
    @assert isbinding(ack, vote, hasher(deme))
    @assert verify(ack, crypto(deme))

    store!(instance.store, vote.seq, ack)

    guard = CastGuard(proposal, vote, ack)
    instance.guard = guard

    return
end


function cast_vote!(voter::DemeAccount, identifier::Union{UUID, Int}, selection; force = false, seq = nothing)

    instance = get_proposal_instance(voter, identifier)

    @assert index(instance.proposal) > index(voter) "You are not eligiable to vote on this proposal as it is anchored to a state before your membership were registered"
    @assert iseligiable(voter, instance.proposal) "You are not eligiable to vote on this proposal as your membership has been terminated"
    cast_vote!(instance, voter.deme, selection, voter.signer; server = voter.route, force, seq)

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

    store!(instance.store, ack)

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

function track_vote(server::Route, proposal::UUID, code::Vector{UInt8})

    host = destination(server) |> string
    request = Request("GET", "/poolingstation/$proposal/track", ["Host" => host])

    credential = TempAccessCodes.credential(code)

    response = request |> AuthClientMiddleware(server, credential, code)

    if response.status == 200
        #return json(response) 
        return unmarshal(response.body)
    else
        error("Request failure $(response.status): $(String(response.body))")
    end
end

track_vote(server::Route, proposal::UUID, code::String) = track_vote(server, proposal, decode_crockford_base32(replace(code, "-"=>"")))

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


# Parser.marshal, Parser.unmarshal ; Client.enroll method seems like a good fit where to do parsing 


function enroll!(invite::Invite; server::Route = route(invite.route), key::Union{Integer, Nothing} = nothing, skip_registration = false, dir = "")
    
    spec = get_deme(server) # Store
    @assert isbinding(spec, invite)
    
    if isempty(dir)
        store = DummyStore()
    else
        #store = AccountStore(dir, spec.uuid)
        store = AccountStore(dir, spec.uuid, invite.token)
    end

    store!(store, spec)
    store!(store, invite)

    if isnothing(key)
        account = DemeAccount(spec, server; store) # Store key
    else
        account = DemeAccount(spec, key, server; store)
    end

    store!(store, account.signer)

    enroll!(account, server, invite; skip_registration)
    
    return account
end


struct DemeClient
    accounts::Vector{DemeAccount}
    dir::String
end


DemeClient(; dir = "") = DemeClient(DemeAccount[], dir)


function enroll!(client::DemeClient, invite::Invite; server::Route = route(invite.route), key = nothing) 

    account = enroll!(invite; server, key, dir = client.dir)
    push!(client.accounts, account)

    return account
end


function select(client::DemeClient, uuid::UUID)

    @warn "This function shall be deprecated in faavour of get"

    for a in client.accounts

        if a.deme.uuid == uuid
            return a
        end

    end

    error("No deme with $uuid found")

end

function Base.get(null::Function, client::DemeClient, uuid::UUID)

    for a in client.accounts
        if a.deme.uuid == uuid
            return a
        end
    end
    
    return null()
end

function Base.get(client::DemeClient, uuid::UUID)
    get(client, uuid) do
        error("Can't find the client with given uuid")
    end
end


update_deme!(client::DemeClient, uuid::UUID) = update_deme!(get(client, uuid))

list_proposal_instances(client::DemeClient, uuid::UUID) = list_proposal_instances(get(client, uuid))

cast_vote!(client::DemeClient, uuid::UUID, index::Int, selection; force=false, seq=nothing) = cast_vote!(get(client, uuid), index, selection; force, seq)

check_vote!(client::DemeClient, uuid::UUID, index::Int) = check_vote!(get(client, uuid), index)

Model.istallied(client::DemeClient, uuid::UUID, index::Int) = istallied(get(client, uuid), index)

get_ballotbox_commit!(client::DemeClient, uuid::UUID, index::Int) = get_ballotbox_commit!(get(client, uuid), index)

get_proposal_instance(client::DemeClient, uuid::UUID, index::Int) = get_ballotbox_commit!(get(client, uuid), index)
get_proposal_instance(client::DemeClient, uuid::UUID, proposal::UUID) = get_ballotbox_commit!(get(client, uuid), proposal)


reset!(client::DemeClient) = empty!(client.accounts)

# Contains also loading primitives and etc.
include("store.jl")

end
