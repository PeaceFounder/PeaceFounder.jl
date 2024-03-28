module Mapper

import Dates: Dates, DateTime
using Base: UUID
using URIs: URI

using ..Schedulers: Schedulers, Scheduler, next_event
using ..Core.Model: Model, CryptoSpec, pseudonym, TicketID, Membership, Proposal, Ballot, Selection, Transaction, Signer, Pseudonym, Vote, id, DemeSpec, Digest, Admission, Generator, GroupSpec, Commit, ChainState, BallotBoxState, CastRecord, BallotBoxLedger
using ..Controllers: Controllers, Registrar, Ticket, BraidChainController, PollingStation, BallotBoxController
using ..Core: Store, Parser
using ..Core.Parser: marshal


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

global DATA_DIR::String = ""

function store(record::Transaction, index::Int)

    !isempty(DATA_DIR) || return

    chain_dir = joinpath(DATA_DIR, "public", "braidchain")
    mkpath(chain_dir)
    Store.save(record, chain_dir, index)
    
    return
end


function store(commit::Commit{ChainState})

    !isempty(DATA_DIR) || return

    commit_path = joinpath(DATA_DIR, "public", "braidchain", "commit.json")
    #Store.save(commit, chain_dir)
    
    rm(commit_path, force=true)
    write(commit_path, Parser.marshal(commit))

    return
end

function load_chain_commit()

    commit_path = joinpath(DATA_DIR, "public", "braidchain", "commit.json")

    if isfile(commit_path)
        return Parser.unmarshal(read(commit_path), Commit{ChainState})
    else
        return nothing
    end
end


function store(commit::Commit{BallotBoxState}, uuid::UUID)

    !isempty(DATA_DIR) || return

    if ispublic(uuid)
        commit_path = joinpath(DATA_DIR, "public", "ballotboxes", string(uuid), "commit.json")
    else
        commit_path = joinpath(DATA_DIR, "private", "ballotboxes", string(uuid), "commit.json")
    end

    mkpath(dirname(commit_path))
    rm(commit_path, force=true)
    write(commit_path, Parser.marshal(commit))

    return
end

function load_bbox_commit(uuid::UUID)

    if ispublic(uuid)
        commit_path = joinpath(DATA_DIR, "public", string(uuid), "commit.json")
    else
        commit_path = joinpath(DATA_DIR, "private", string(uuid), "commit.json")
    end

    return Parser.unmarshal(commit_path, Commit{BallotBoxState})
end


function store(signer::Signer, role::Symbol)
    
    !isempty(DATA_DIR) || return

    key_file = joinpath(DATA_DIR, "secret", "$role.json")
    mkpath(dirname(key_file))

    write(key_file, Parser.marshal(signer))

    return
end


function load_signer(role::Symbol)

    key_file = joinpath(DATA_DIR, "secret", "$role.json")

    if isfile(key_file)
        return Parser.unmarshal(read(key_file), Signer)
    else
        return nothing
    end
end


# It could also be named as isreleased
function ispublic(uuid::UUID)

    commit = get_ballotbox_commit(uuid)
    
    return !isnothing(commit.state.tally)
end

# This will be moved in a stored vector type;
# Path will be adjusted of the ledger manually so that it would always point to the right place.
function store(record::CastRecord, uuid::UUID, index::Int)

    !isempty(DATA_DIR) || return

    public_bbox_dir = joinpath(DATA_DIR, "public", "ballotboxes", string(uuid)) # when votes are released
    private_bbox_dir = joinpath(DATA_DIR, "private", "ballotboxes", string(uuid)) # before the release

    # Note that this would not make issues because storage operation are on a single main thread
    # Unfortunatelly hardlinks on folders are not supported. I could do that recursivelly though on files
    if ispublic(uuid)
        mkpath(public_bbox_dir)
        Store.save(record, public_bbox_dir, index)
    else
        mkpath(private_bbox_dir)
        Store.save(record, private_bbox_dir, index)
    end

    return
end


function make_bbox_store_public(uuid::UUID)
    
    !isempty(DATA_DIR) || return

    public_bbox_dir = joinpath(DATA_DIR, "public", "ballotboxes", string(uuid)) # when votes are released
    private_bbox_dir = joinpath(DATA_DIR, "private", "ballotboxes", string(uuid)) # before the release

    if isdir(private_bbox_dir)

        mkpath(dirname(public_bbox_dir))
        rm(public_bbox_dir, force=true) # If direcotry is nonempty it would throw an error
        mv(private_bbox_dir, public_bbox_dir)

    end

    return
end


function init_bbox_store(ledger::BallotBoxLedger)

    !isempty(DATA_DIR) || return
    
    private_bbox_dir = joinpath(DATA_DIR, "private", "ballotboxes", string(ledger.proposal.uuid)) # before the release
    mkpath(dirname(private_bbox_dir))

    Store.save(ledger, private_bbox_dir)    

    return
end


function entropy_process_loop()
    
    uuid = wait(ENTROPY_SCHEDULER)
    bbox = get(POLLING_STATION[], uuid) # bbox = Model.ballotbox(POLLING_STATION[], uuid)

    if isnothing(bbox.commit)

        spec = bbox.ledger.spec
        _seed = Model.digest(rand(UInt8, 16), Model.hasher(spec))
        Controllers.set_seed!(bbox, _seed)
        Controllers.commit!(bbox, COLLECTOR[]; with_tally = false)

    end

    #init_bbox_store(Controllers.ledger(bbox)) # 

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
    
    _ispublic = ispublic(uuid)

    tally_votes!(uuid)

    if !_ispublic
        try
            make_bbox_store_public(uuid)
        catch err
            @warn "Failing to make balltobox with $uuid public"
        end
    end

    return
end

function reset_system()

    BRAID_CHAIN[] = nothing # The braidchain needs to be loaded within a setup
    POLLING_STATION[] = nothing
    RECORDER[] = nothing
    REGISTRAR[] = nothing
    BRAIDER[] = nothing
    PROPOSER[] = nothing
    COLLECTOR[] = nothing

    # I need a way to kill a task that waits on condition
    #ENTROPY_SCHEDULER.condition = Condition()
    #TALLY_SCHEDULER.condition = Condition()

    return
end

# Note that preferences would be stored and loaded by PeaceFounderAdmin instead
function load_system() # a kwarg could be passed on whether to audit the system

    @assert !isempty(readdir(DATA_DIR)) "State can't be loaded, data direcotry is empty."

    # The auditing shall only concern itself by evaluating a treehash of the ledger and comparing that with the commit
    # that can in fact be better done within the BraidChainController constructor!

    chain_ledger = Store.load(joinpath(DATA_DIR, "public", "braidchain"))
    chain_commit = load_chain_commit()
    
    BRAID_CHAIN[] = BraidChainController(chain_ledger, commit = chain_commit)

    # I should iterate over all BRAID_CHAIN records and find a proposal
    
    POLLING_STATION[] = PollingStation()

    for record in chain_ledger
        
        if record isa Proposal

            proposal = record

            _voters = Model.voters(chain_ledger, proposal.anchor)

            # warn if ballotbox for proposal can not be found!

            bbox_public_dir = joinpath(DATA_DIR, "public", "ballotboxes", string(proposal.uuid))
            bbox_private_dir = joinpath(DATA_DIR, "private", "ballotboxes", string(proposal.uuid))

            # I could add try catch here after this will be tested
            if isdir(bbox_public_dir)
                bbox_dir = bbox_public_dir
            elseif isdir(bbox_private_dir)
                bbox_dir = bbox_private_dir
            else
                @warn "BallotBox for proposal with uuid $(proposal.uuid) not found and thus is unitialized. "
                # If voting has not yet started then this is a place where it could be initialized
            end

            bbox_ledger = Store.load(bbox_dir)

            #bbox_commit = load_bbox_commit(proposal.uuid) 
            bbox_commit = Parser.unmarshal(joinpath(bbox_dir, "commit.json"), Commit{BallotBoxState})
            bbox = BallotBoxController(bbox_ledger, _voters; commit=bbox_commit)

            if bbox_commit == nothing && length(bbox_ledger) > 0
                @warn "BallotBox commit not found. A new seed will be set."
            end
            
            Controllers.init!(POLLING_STATION[], bbox)

            Schedulers.schedule!(ENTROPY_SCHEDULER, proposal.open, proposal.uuid)
            Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)
        end
    end

    RECORDER[] = load_signer(:recorder)
    
    registrar = load_signer(:registrar)
    hmac_key = Model.bytes(Model.digest(Vector{UInt8}(string(registrar.key)), registrar.spec)) # 
    REGISTRAR[] = Registrar(registrar, hmac_key)
    Controllers.set_demehash!(REGISTRAR[], BRAID_CHAIN[].spec) 

    BRAIDER[] = load_signer(:braider)

    PROPOSER[] = load_signer(:proposer)

    COLLECTOR[] = load_signer(:collector)

    if !isnothing(COLLECTOR[])
        ENTROPY_PROCESS[] = @async while true
            entropy_process_loop()
        end

        TALLY_PROCESS[] = @async while true
            tally_process_loop()
        end
    end

    return authorized_roles(BRAID_CHAIN[].spec)
end


function setup(demefunc::Function, groupspec::GroupSpec, generator::Generator)

    reset_system()

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

    if !isempty(DATA_DIR)
        
        mkpath(joinpath(DATA_DIR, "public",  "braidchain", "memberships"))
        mkpath(joinpath(DATA_DIR, "public", "braidchain", "demespecs"))
        mkpath(joinpath(DATA_DIR, "public", "braidchain", "braidreceipts"))
        mkpath(joinpath(DATA_DIR, "public", "braidchain", "proposals"))

    end

    if isnothing(POLLING_STATION[])
        POLLING_STATION[] = PollingStation()
    end


    N = findfirst(x->x==demespec.recorder, pseudonym_list)
    if !isnothing(N)
        RECORDER[] = Signer(demespec.crypto, generator, key_list[N])
        store(RECORDER[], :recorder)
        
        N = Controllers.record!(BRAID_CHAIN[], demespec)
        store(demespec, N)
        Controllers.commit!(BRAID_CHAIN[], RECORDER[]) 
        store(Model.commit(BRAID_CHAIN[]))

        BRAID_BROKER_PROCESS[] = @async while true
            broker_process_loop()
        end
    end
    
    N = findfirst(x->x==demespec.registrar, pseudonym_list)
    if !isnothing(N)
        signer = Signer(demespec.crypto, generator, key_list[N])
        store(signer, :registrar)
        hmac_key = Model.bytes(Model.digest(Vector{UInt8}(string(key_list[N])), demespec.crypto)) # 
        REGISTRAR[] = Registrar(signer, hmac_key)
        Controllers.set_demehash!(REGISTRAR[], demespec) 
    end

    N = findfirst(x->x==demespec.braider, pseudonym_list)
    if !isnothing(N)
        BRAIDER[] = Signer(demespec.crypto, generator, key_list[N])
        store(BRAIDER[], :braider)
    end

    N = findfirst(x->x==demespec.proposer, pseudonym_list)
    if !isnothing(N)
        PROPOSER[] = Signer(demespec.crypto, generator, key_list[N])
        store(PROPOSER[], :proposer)
    end    

    N = findfirst(x->x==demespec.collector, pseudonym_list)
    if !isnothing(N)
        COLLECTOR[] = Signer(demespec.crypto, generator, key_list[N])
        store(COLLECTOR[], :collector)

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

    # Notes on concurrency
    # If braiding is in process, membership records need to be dropped;
    # Membership and Proposal records can be recorded concurently; (a lockable vector would ensure integrity)
    # Change of DemeSpec record requires shutdown of the service. I could have a semaphore to detect that 
    # and a state variable which indicates closing of the service in which case all records are dropped.
    
    N = Controllers.record!(BRAID_CHAIN[], transaction)
    store(transaction, N)
    Controllers.commit!(BRAID_CHAIN[], RECORDER[])
    store(Model.commit(BRAID_CHAIN[]))

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
    store(proposal, N)
    Controllers.commit!(BRAID_CHAIN[], RECORDER[])
    store(Model.commit(BRAID_CHAIN[]))

    spec = get_demespec()
    #anchored_members = Model.members(BRAID_CHAIN[], proposal)
    anchored_members = Model.voters(BRAID_CHAIN[], proposal) # I could get a braid output_members
    Controllers.init!(POLLING_STATION[], spec, proposal, anchored_members)

    init_bbox_store(Controllers.ledger(get(POLLING_STATION[], proposal)))

    Schedulers.schedule!(ENTROPY_SCHEDULER, proposal.open, proposal.uuid)
    Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)

    ack = Controllers.ack_leaf(BRAID_CHAIN[], N)
    return ack
end


function cast_vote(uuid::UUID, vote::Vote; late_votes = false)

    if !(Model.isstarted(get_proposal(uuid); time = Dates.now()))

        error("Voting have not yet started")

    elseif !late_votes && Model.isdone(get_proposal(uuid); time = Dates.now())

        error("Vote received for proposal too late")
        
    else
        # Concurency can be used with a following API but it requires defining 
        # a new vector type which has a write lock.

        bbox = get(POLLING_STATION[], uuid)        
        N = Controllers.record!(bbox, vote)

        # commit! may make dublicates in cases when record! executed async
        # this is not a big issue. We are mainly concerned with validating records fast
        # and selecting needles from a haystack
        Controllers.commit!(bbox, COLLECTOR[])

        # the disk storage will happen with the vector, thus commit would not be anounced before
        # it would be backed by a persitent disk record.
        store(bbox[N], uuid, N)
        store(Model.commit(bbox), uuid)
        

        ack = Controllers.ack_cast(POLLING_STATION[], uuid, N)
        return ack
    end
end

#@deprecate cast_vote! cast_vote

#ballotbox(uuid::UUID) = get(POLLING_STATION[], uuid)
get_ballotbox(uuid::UUID) = get(POLLING_STATION[], uuid)

#@deprecate ballotbox get_ballotbox

#proposal(uuid::UUID) = get_ballotbox(uuid).ledger.proposal
get_proposal(uuid::UUID) = get_ballotbox(uuid).ledger.proposal 

#@deprecate proposal get_proposal

#tally(uuid::UUID) = ballotbox(uuid).tally
get_tally(uuid::UUID) = ballotbox(uuid).tally

#@deprecate tally get_tally

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
