module Mapper
# Initialization of global variables and coresponding methods to it
# Service layer puts more abstrction. Probably unnecessary.

import Sockets
import Dates: Dates, DateTime
import ..Schedulers: Schedulers, Scheduler

using ..Model
using ..Model: CryptoSpec, pseudonym, BraidChain, Registrar, PollingStation, TicketID, Member, Proposal, Ballot, Selection, Transaction, Signer, Dealer, BraidBroker, Pseudonym, Vote, id, DemeSpec, Digest, Admission, Ticket
using Base: UUID
using URIs: URI

const RECORDER = Ref{Signer}()
const REGISTRAR = Ref{Registrar}()
const BRAIDER = Ref{Signer}()
const COLLECTOR = Ref{Signer}()

const BRAID_CHAIN = Ref{BraidChain}()

# to prevent members registering while braiding happens and other way around.
# islocked() == false => lock else error in the case for a member
# wheras for braiding imediately lock is being waited for
const MEMBER_LOCK = ReentrantLock()

const POLLING_STATION = Ref{PollingStation}()
const TALLY_SCHEDULER = Scheduler(UUID, retry_interval = 5) 
const TALLY_PROCESS = Ref{Task}()

const DEALER = Ref{Dealer}()
const DEALER_SCHEDULER = Scheduler(retry_interval = 1)
const DEALER_PROCESS = Ref{Task}()

const BRAID_BROKER = Ref{BraidBroker}
const BRAID_BROKER_SCHEDULER = Scheduler(retry_interval = 5)
const BRAID_BROKER_PROCESS = Ref{Task}()


function dealer_process_loop(; force = false)

    force || isready(DEALER[]) || wait(DEALER_SCHEDULER)
    isready(DEALER[]) || return # for false triggers with pooling interval

    job = Model.next_job(DEALER[])

    try 
        pulse = Model.get_pulse(DEALER[].beacon, job.timestamp) # retriving nothing seems plausable
        Model.cast!(DEALER[], job.uuid, pulse)
    catch
        # In real code instead a notification would be scheduled at time ahead.
        #retry!(DEALER_SCHEDULER)
        Model.pass!(DEALER[], job.uuid)
    end

    lot = Model.draw(DEALER[], job.uuid)
    Model.record!(BRAID_CHAIN[], lot)
    Model.commit!(BRAID_CHAIN[], RECORDER[])

    _seed = Model.seed(lot)
    Model.set_seed!(POLLING_STATION[], job.uuid, _seed)
    Model.commit!(POLLING_STATION[], job.uuid, COLLECTOR[]; with_tally = false)

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


    record!(BRAID_CHAIN[], _braid)
    commit!(BRAID_CHAIN[], RECORDER[])

    return
end


tally_votes!(uuid::UUID) = Model.commit!(POLLING_STATION[], uuid, COLLECTOR[]; with_tally = true);

function tally_process_loop()
    
    uuid = wait(TALLY_SCHEDULER)
    tally_votes!(uuid)

    return
end


function initialize!(spec::CryptoSpec)

    RECORDER[] = Model.generate(Signer, spec)
    REGISTRAR[] = Model.generate(Registrar, spec)
    BRAIDER[] = Model.generate(Signer, spec)
    COLLECTOR[] = Model.generate(Signer, spec)

    return
end

system_roles() = (; recorder = id(RECORDER[]), registrar = id(REGISTRAR[]), braider = id(BRAIDER[]), collector = id(COLLECTOR[]))


set_demehash(spec::DemeSpec) = Model.set_demehash!(REGISTRAR[], spec)
set_route(route::Union{URI, String}) = Model.set_route!(REGISTRAR[], route)
get_route() = REGISTRAR[].route

function capture!(spec::DemeSpec)

    BRAID_CHAIN[] = BraidChain(spec)

    set_demehash(spec)

    #REGISTRAR[].demehash = Model.digest(spec, Model.hasher(spec))

    DEALER[] = Dealer(spec; delay = 1)

    POLLING_STATION[] = PollingStation(Model.crypto(spec))

    promises = Model.charge_nonces!(DEALER[], 100; reset = true)
    Model.record!(BRAID_CHAIN[], promises)

    Model.commit!(BRAID_CHAIN[], RECORDER[]) # Errors if the braidchain server is not accepted. An option override=true could be provided 

    DEALER_PROCESS[] = @async while true
        dealer_process_loop()
    end

    BRAID_BROKER_PROCESS[] = @async while true
        braidchain_process_loop()
    end

    TALLY_PROCESS[] = @async while true
        tally_process_loop()
    end

    return
end


get_recruit_key() = Model.key(REGISTRAR[])

get_deme() = BRAID_CHAIN[].spec

#enlist_ticket(ticketid::TicketID, timestamp::DateTime, auth_code::Digest; expiration_time = nothing) = Model.enlist!(REGISTRAR[], ticketid, timestamp, auth_code)

enlist_ticket(ticketid::TicketID, timestamp::DateTime; expiration_time = nothing) = Model.enlist!(REGISTRAR[], ticketid, timestamp)
enlist_ticket(ticketid::TicketID; expiration_time = nothing) = enlist_ticket(ticketid, Dates.now(); expiration_time)

# Useful for an admin
#delete_ticket!(ticketid::TicketID) = Model.remove!(REGISTRAR[], ticketid) # 

get_ticket_ids() = Model.ticket_ids(REGISTRAR[])

get_ticket_status(ticketid::TicketID) = Model.ticket_status(ticketid, REGISTRAR[])
get_ticket_admission(ticketid::TicketID) = Model.select(Admission, ticketid, REGISTRAR[])
get_ticket_timestamp(ticketid::TicketID) = Model.select(Ticket, ticketid, REGISTRAR[]).timestamp

get_ticket(tokenid::AbstractString) = Model.select(Ticket, tokenid, REGISTRAR[])

# The benfit of refering to a single ticketid is that it is long lasting
seek_admission(id::Pseudonym, ticketid::TicketID) = Model.admit!(REGISTRAR[], id, ticketid) 
get_admission(id::Pseudonym) = Model.select(Admission, id, REGISTRAR[])
list_admissions() = [i.admission for i in REGISTRAR[].tickets]

get_chain_roll() = Model.roll(BRAID_CHAIN[])
get_member(_id::Pseudonym) = filter(x -> Model.id(x) == _id, list_members())[1] # Model.select

get_chain_commit() = Model.commit(BRAID_CHAIN[])

function submit_chain_record!(transaction::Transaction) 

    N = Model.record!(BRAID_CHAIN[], transaction)
    Model.commit!(BRAID_CHAIN[], RECORDER[])

    ack = Model.ack_leaf(BRAID_CHAIN[], N)
    return ack
end

get_chain_record(N::Int) = BRAID_CHAIN[][N]
get_chain_ack_leaf(N::Int) = Model.ack_leaf(BRAID_CHAIN[], N)
get_chain_ack_root(N::Int) = Model.ack_root(BRAID_CHAIN[], N)

enroll_member(member::Member) = submit_chain_record!(member)
enlist_proposal(proposal::Proposal) = submit_chain_record!(proposal)

get_roll() = Model.roll(BRAID_CHAIN[])

get_peers() = Model.peers(BRAID_CHAIN[])

get_constituents() = Model.constituents(BRAID_CHAIN[])

reset_tree() = Model.reset_tree!(BRAID_CHAIN[])

get_members(N::Int) = Model.members(BRAID_CHAIN[], N)
get_members() = Model.members(BRAID_CHAIN[])

get_generator(N::Int) = Model.generator(BRAID_CHAIN[], N)
get_generator() = Model.generator(BRAID_CHAIN[])

get_chain_proposal_list() = collect(Model.list(Proposal, BRAID_CHAIN[]))


function schedule_pulse!(uuid::UUID, timestamp, nonceid)
    
    Model.schedule!(DEALER[], uuid, timestamp, nonceid)
    Schedulers.schedule!(DEALER_SCHEDULER, timestamp)

    return
end


function submit_chain_record!(proposal::Proposal)

    N = Model.record!(BRAID_CHAIN[], proposal)
    Model.commit!(BRAID_CHAIN[], RECORDER[])

    Model.add!(POLLING_STATION[], proposal, Model.members(BRAID_CHAIN[], proposal))

    timestamp = Model.pulse_timestamp(BRAID_CHAIN[], proposal.uuid)
    nonceid = Model.nonce_promise(BRAID_CHAIN[], proposal.uuid)

    schedule_pulse!(proposal.uuid, timestamp, nonceid)

    Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)

    ack = Model.ack_leaf(BRAID_CHAIN[], N)
    return ack
end


function cast_vote(uuid::UUID, vote::Vote; late_votes = false)

    if !(Model.isstarted(proposal(uuid); time = Dates.now()))

        error("Voting have not yet started")

    elseif !late_votes && Model.isdone(proposal(uuid); time = Dates.now())

        error("Vote received for proposal too late")
        
    else
        # need to bounce back if not within window. It could still be allowed to 

        N = Model.record!(POLLING_STATION[], uuid, vote)
        Model.commit!(POLLING_STATION[], uuid, COLLECTOR[])

        ack = Model.ack_cast(POLLING_STATION[], uuid, N)
        return ack
    end
end

@deprecate cast_vote! cast_vote

ballotbox(uuid::UUID) = Model.ballotbox(POLLING_STATION[], uuid)
proposal(uuid::UUID) = ballotbox(uuid).proposal
tally(uuid::UUID) = ballotbox(uuid).tally

get_ballotbox_commit(uuid::UUID) = Model.commit(POLLING_STATION[], uuid)

get_ballotbox_ack_leaf(uuid::UUID, N::Int) = Model.ack_leaf(POLLING_STATION[], uuid, N)
get_ballotbox_ack_root(uuid::UUID, N::Int) = Model.ack_root(POLLING_STATION[], uuid, N)

get_ballotbox_spine(uuid::UUID) = Model.spine(POLLING_STATION[], uuid)

function get_ballotbox_record(uuid::UUID, N::Int; fairness::Bool = true)
   
    bbox = Model.ballotbox(PollingStation[], uuid)        
    
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        Model.record(bbox, N)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end

get_ballotbox_receipt(uuid::UUID, N::Int) = Model.receipt(POOLING_STATION[], uuid, N)


function get_ballotbox_ledger(uuid::UUID; fairness::Bool = true, tally_trigger_delay::Union{Nothing, Int} = nothing)

    bbox = Model.ballotbox(PollingStation[], uuid)        

    trigger_tally!(uuid; tally_trigger_delay)
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        Model.ledger(bbox)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end



end
