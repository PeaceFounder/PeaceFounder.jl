module Mapper

import Dates: Dates, DateTime
using Base: UUID
using URIs: URI

using ..Schedulers: Schedulers, Scheduler, next_event
using ..Core.Model: Model, CryptoSpec, pseudonym, TicketID, Membership, Proposal, Ballot, Selection, Transaction, Signer, Pseudonym, Vote, id, DemeSpec, Digest, Admission, Generator, GroupSpec
using ..Controllers: Controllers, Registrar, Ticket, BraidChainController, PollingStation

const RECORDER = Ref{Union{Signer, Nothing}}(nothing)
const REGISTRAR = Ref{Union{Registrar, Nothing}}(nothing)
const BRAIDER = Ref{Union{Signer, Nothing}}(nothing)
const COLLECTOR = Ref{Union{Signer, Nothing}}(nothing)
const PROPOSER = Ref{Union{Signer, Nothing}}(nothing)

# to prevent members registering while braiding happens and other way around.
# islocked() == false => lock else error in the case for a member
# wheras for braiding imediately lock is being waited for
const MEMBER_LOCK = ReentrantLock()
const BRAID_CHAIN = Ref{Union{BraidChainController, Nothing}}(nothing)

const POLLING_STATION = Ref{Union{PollingStation, Nothing}}(nothing)
const TALLY_SCHEDULER = Scheduler(UUID, retry_interval = 5) 
const TALLY_PROCESS = Ref{Task}()

const ENTROPY_SCHEDULER = Scheduler(retry_interval = 1)
const ENTROPY_PROCESS = Ref{Task}()

#const BRAID_BROKER = Ref{BraidBroker}
const BRAID_BROKER_SCHEDULER = Scheduler(retry_interval = 5)
const BRAID_BROKER_PROCESS = Ref{Task}()


function entropy_process_loop()
    
    uuid = wait(ENTROPY_SCHEDULER)
    bbox = get(POLLING_STATION[], uuid) # bbox = Model.ballotbox(POLLING_STATION[], uuid)

    if isnothing(bbox.commit)

        spec = BRAID_CHAIN[].spec
        _seed = Model.digest(rand(UInt8, 16), Model.hasher(spec))
        Controllers.set_seed!(bbox, _seed)
        Controllers.commit!(bbox, COLLECTOR[]; with_tally = false)

    end

    return
end


function broker_process_loop(; force = false)

    force || wait(BRAID_BROKER_SCHEDULER)
    # no pooling thus no false triggers are expected here

    lock(MEMBER_LOCK)

    try
        _members = members(BRAID_CHAIN[])
        _braid = braid(BRAIDER_BROKER[], _members) # one is selected at random from all available options
    catch
        retry!(BRAID_BROKER_SCHEDULER)
    finally
        unlock(MEMBER_LOCK)
    end


    Controllers.record!(BRAID_CHAIN[], _braid)
    Controllers.commit!(BRAID_CHAIN[], RECORDER[])

    return
end

function tally_process_loop()
    
    uuid = wait(TALLY_SCHEDULER)
    tally_votes!(uuid)

    return
end


function setup(demefunc::Function, groupspec::GroupSpec, generator::Generator)

    BRAID_CHAIN[] = nothing # The braidchain needs to be loaded within a setup
    POLLING_STATION[] = nothing
    RECORDER[] = nothing
    REGISTRAR[] = nothing
    BRAIDER[] = nothing
    PROPOSER[] = nothing
    COLLECTOR[] = nothing

    key_list = Integer[]
    pseudonym_list = Pseudonym[]

    for i in 1:5
        (key, pseudonym) = Model.keygen(groupspec, generator)
        push!(key_list, key)
        push!(pseudonym_list, pseudonym)
    end

    demespec = demefunc(pseudonym_list)

    @assert groupspec == demespec.crypto.group "GroupSpec does not match argument"
    @assert Model.verify(demespec, demespec.crypto) "DemeSpec is not corectly signed"

    # This covers a situation where braidchain is initialized externally
    # more work would need to be put to actually support that though
    if isnothing(BRAID_CHAIN[])
        BRAID_CHAIN[] = BraidChainController(demespec)
    end

    if isnothing(POLLING_STATION[])
        POLLING_STATION[] = PollingStation()
    end


    N = findfirst(x->x==demespec.recorder, pseudonym_list)
    if !isnothing(N)
        RECORDER[] = Signer(demespec.crypto, generator, key_list[N])
        Controllers.record!(BRAID_CHAIN[], demespec)
        Controllers.commit!(BRAID_CHAIN[], RECORDER[]) 
    
        BRAID_BROKER_PROCESS[] = @async while true
            broker_process_loop()
        end
    end
    
    N = findfirst(x->x==demespec.registrar, pseudonym_list)
    if !isnothing(N)
        signer = Signer(demespec.crypto, generator, key_list[N])
        hmac_key = Model.bytes(Model.digest(Vector{UInt8}(string(key_list[N])), demespec.crypto)) # 
        REGISTRAR[] = Registrar(signer, hmac_key)
        Controllers.set_demehash!(REGISTRAR[], demespec) 
    end

    N = findfirst(x->x==demespec.braider, pseudonym_list)
    if !isnothing(N)
        BRAIDER[] = Signer(demespec.crypto, generator, key_list[N])
    end

    N = findfirst(x->x==demespec.proposer, pseudonym_list)
    if !isnothing(N)
        PROPOSER[] = Signer(demespec.crypto, generator, key_list[N])
    end    

    N = findfirst(x->x==demespec.collector, pseudonym_list)
    if !isnothing(N)
        COLLECTOR[] = Signer(demespec.crypto, generator, key_list[N])
   
        ENTROPY_PROCESS[] = @async while true
            entropy_process_loop()
        end

        TALLY_PROCESS[] = @async while true
            tally_process_loop()
        end
    end    

    return authorized_roles(demespec) # I may deprecate this in favour of a method.
end


function authorized_roles(demespec::DemeSpec)

    roles = []

    if !isnothing(RECORDER[]) && id(RECORDER[]) == demespec.recorder
        push!(roles, :recorder)
    end

    if !isnothing(REGISTRAR[]) && id(REGISTRAR[]) == demespec.registrar
        push!(roles, :registrar)
    end

    if !isnothing(BRAIDER[]) && id(BRAIDER[]) == demespec.braider
        push!(roles, :braider)
    end

    if !isnothing(COLLECTOR[]) && id(COLLECTOR[]) == demespec.collector
        push!(roles, :collector)
    end

    if !isnothing(PROPOSER[]) && id(PROPOSER[]) == demespec.proposer
        push!(roles, :proposer)
    end

    return roles
end


# Need to decide on whether this would be more appropriate
#system_roles() = (; recorder = id(RECORDER[]), registrar = id(REGISTRAR[]), braider = id(BRAIDER[]), collector = id(COLLECTOR[]))
tally_votes!(uuid::UUID) = Controllers.commit!(POLLING_STATION[], uuid, COLLECTOR[]; with_tally = true);

set_demehash(spec::DemeSpec) = Controllers.set_demehash!(REGISTRAR[], spec)
set_route(route::Union{URI, String}) = Controllers.set_route!(REGISTRAR[], route)
get_route() = REGISTRAR[].route

get_recruit_key() = Model.key(REGISTRAR[])

#get_deme() = BRAID_CHAIN[].spec
get_demespec() = BRAID_CHAIN[].spec

enlist_ticket(ticketid::TicketID, timestamp::DateTime; expiration_time = nothing, reset=false) = Controllers.enlist!(REGISTRAR[], ticketid, timestamp; reset)
enlist_ticket(ticketid::TicketID; expiration_time = nothing, reset=false) = enlist_ticket(ticketid, Dates.now(); expiration_time, reset)

# Useful for an admin
#delete_ticket!(ticketid::TicketID) = Model.remove!(REGISTRAR[], ticketid) # 

get_ticket_ids() = Controllers.ticket_ids(REGISTRAR[])

get_ticket_status(ticketid::TicketID) = Controllers.ticket_status(ticketid, REGISTRAR[])
get_ticket_admission(ticketid::TicketID) = Model.select(Admission, ticketid, REGISTRAR[]) # TODO: use get instead
get_ticket_timestamp(ticketid::TicketID) = Model.select(Ticket, ticketid, REGISTRAR[]).timestamp

get_ticket(tokenid::AbstractString) = Model.select(Ticket, tokenid, REGISTRAR[]) 
get_ticket(ticketid::TicketID) = Model.select(Ticket, ticketid, REGISTRAR[])

function delete_ticket(ticketid::TicketID)
    
    ticket_index = findfirst(x -> x.ticketid == ticketid, REGISTRAR[].tickets)
    ticket = REGISTRAR[].tickets[ticket_index]

    @assert isnothing(ticket.admission) "Ticket's can't be removed after admitted. May be allowed in the future with membership termination."

    deleteat!(Mapper.REGISTRAR[].tickets, ticket_index)

    return
end


# The benfit of refering to a single ticketid is that it is long lasting
seek_admission(id::Pseudonym, ticketid::TicketID) = Controllers.admit!(REGISTRAR[], id, ticketid) 
get_admission(id::Pseudonym) = Model.select(Admission, id, REGISTRAR[])
list_admissions() = [i.admission for i in REGISTRAR[].tickets]

get_chain_roll() = Controllers.roll(BRAID_CHAIN[])
get_member(_id::Pseudonym) = filter(x -> Model.id(x) == _id, list_members())[1] # Model.select

get_chain_commit() = Model.commit(BRAID_CHAIN[])

function submit_chain_record!(transaction::Transaction) 

    N = Controllers.record!(BRAID_CHAIN[], transaction)
    Controllers.commit!(BRAID_CHAIN[], RECORDER[])

    ack = Controllers.ack_leaf(BRAID_CHAIN[], N)
    return ack
end

get_chain_record(N::Int) = BRAID_CHAIN[][N]
get_chain_ack_leaf(N::Int) = Controllers.ack_leaf(BRAID_CHAIN[], N)
get_chain_ack_root(N::Int) = Controllers.ack_root(BRAID_CHAIN[], N)

enroll_member(member::Membership) = submit_chain_record!(member)
enlist_proposal(proposal::Proposal) = submit_chain_record!(proposal)

get_roll() = Controllers.roll(BRAID_CHAIN[])

get_peers() = Controllers.peers(BRAID_CHAIN[])

get_constituents() = Controllers.constituents(BRAID_CHAIN[])

reset_tree() = Controllers.reset_tree!(BRAID_CHAIN[])

get_members(N::Int) = Model.members(BRAID_CHAIN[], N)
get_members() = Model.members(BRAID_CHAIN[])

get_generator(N::Int) = Model.generator(BRAID_CHAIN[], N)
get_generator() = Model.generator(BRAID_CHAIN[])

get_chain_proposal_list() = collect(Controllers.list(Proposal, BRAID_CHAIN[]))


# function schedule_pulse!(uuid::UUID, timestamp, nonceid)
    
#     Model.schedule!(DEALER[], uuid, timestamp, nonceid)
#     Schedulers.schedule!(DEALER_SCHEDULER, timestamp)

#     return
# end


function submit_chain_record!(proposal::Proposal)

    N = Controllers.record!(BRAID_CHAIN[], proposal)
    Controllers.commit!(BRAID_CHAIN[], RECORDER[])

    spec = get_demespec()
    #anchored_members = Model.members(BRAID_CHAIN[], proposal)
    anchored_members = Model.voters(BRAID_CHAIN[], proposal) # I could get a braid output_members
    Controllers.add!(POLLING_STATION[], spec, proposal, anchored_members)

    Schedulers.schedule!(ENTROPY_SCHEDULER, proposal.open, proposal.uuid)
    Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)

    ack = Controllers.ack_leaf(BRAID_CHAIN[], N)
    return ack
end


function cast_vote(uuid::UUID, vote::Vote; late_votes = false)

    if !(Model.isstarted(proposal(uuid); time = Dates.now()))

        error("Voting have not yet started")

    elseif !late_votes && Model.isdone(proposal(uuid); time = Dates.now())

        error("Vote received for proposal too late")
        
    else
        # need to bounce back if not within window. It could still be allowed to 

        N = Controllers.record!(POLLING_STATION[], uuid, vote)
        Controllers.commit!(POLLING_STATION[], uuid, COLLECTOR[])

        ack = Controllers.ack_cast(POLLING_STATION[], uuid, N)
        return ack
    end
end

@deprecate cast_vote! cast_vote

ballotbox(uuid::UUID) = Controllers.ballotbox(POLLING_STATION[], uuid)
proposal(uuid::UUID) = ballotbox(uuid).ledger.proposal
tally(uuid::UUID) = ballotbox(uuid).tally

get_ballotbox_commit(uuid::UUID) = Model.commit(POLLING_STATION[], uuid)

get_ballotbox_ack_leaf(uuid::UUID, N::Int) = Controllers.ack_leaf(POLLING_STATION[], uuid, N)
get_ballotbox_ack_root(uuid::UUID, N::Int) = Controllers.ack_root(POLLING_STATION[], uuid, N)

get_ballotbox_spine(uuid::UUID) = Controllers.spine(POLLING_STATION[], uuid)

function get_ballotbox_record(uuid::UUID, N::Int; fairness::Bool = true)
   
    bbox = Controllers.ballotbox(PollingStation[], uuid)        
    
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        return bbox[N] # Model.record(bbox, N)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end

get_ballotbox_receipt(uuid::UUID, N::Int) = Model.receipt(POOLING_STATION[], uuid, N)


# The access seems better to be dealt at the topmost level
function get_ballotbox_ledger(uuid::UUID; fairness::Bool = true, tally_trigger_delay::Union{Nothing, Int} = nothing)

    bbox = Controllers.ballotbox(PollingStation[], uuid)        

    # trigger_tally!(uuid; tally_trigger_delay)
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        Controllers.ledger(bbox)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end


end