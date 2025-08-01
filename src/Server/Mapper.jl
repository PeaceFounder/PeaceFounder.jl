module Mapper

import Dates: Dates, DateTime, UTC
using Base: UUID
using URIs: URI

using ..Schedulers: Schedulers, SchedulerActor
using ..Core.Model: Model, CryptoSpec, pseudonym, TicketID, Membership, Proposal, Ballot, Selection, Transaction, Signer, Pseudonym, Vote, id, DemeSpec, Digest, Admission, Generator, GroupSpec, Commit, ChainState, BallotBoxState, CastRecord, BallotBoxLedger
using ..Controllers: Controllers, Registrar, Ticket, BraidChainController, PollingStation, BallotBoxController
using ..Core: Store, Parser
using ..Core.Parser: marshal


global RECORDER::Union{Signer, Nothing}
global REGISTRAR::Union{Registrar, Nothing}
global BRAIDER::Union{Signer, Nothing}
global COLLECTOR::Union{Signer, Nothing}
global PROPOSER::Union{Signer, Nothing}

# to prevent members registering while braiding happens and other way around.
# islocked() == false => lock else error in the case for a member
# wheras for braiding imediately lock is being waited for
const MEMBER_LOCK = ReentrantLock()
global BRAID_CHAIN::Union{BraidChainController, Nothing}

global POLLING_STATION::Union{PollingStation, Nothing}

global TALLY_SCHEDULER::SchedulerActor
global ENTROPY_SCHEDULER::SchedulerActor


global CTIME::Union{DateTime, Nothing} = nothing

function with_ctime(f::Function, ctime::DateTime)
    global CTIME = ctime
    try
        f()
    finally
        global CTIME = nothing
    end
end

now() = isnothing(CTIME) ? Dates.now(UTC) : CTIME # Necessary for mocking purposes


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


function store(commit::Commit{BallotBoxState}, uuid::UUID; public) # may need an update for Julia 1.11

    !isempty(DATA_DIR) || return

    if public
        commit_path = joinpath(DATA_DIR, "public", "ballotboxes", string(uuid), "commit.json")
    else
        commit_path = joinpath(DATA_DIR, "private", "ballotboxes", string(uuid), "commit.json")
    end

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
function store(record::CastRecord, uuid::UUID, index::Int; public)

    !isempty(DATA_DIR) || return

    public_bbox_dir = joinpath(DATA_DIR, "public", "ballotboxes", string(uuid)) # when votes are released
    private_bbox_dir = joinpath(DATA_DIR, "private", "ballotboxes", string(uuid)) # before the release

    # Note that this would not make issues because storage operation are on a single main thread
    # Unfortunatelly hardlinks on folders are not supported. I could do that recursivelly though on files
    if public
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

    # if public direcotry alredy exists does nothing
    ( !isdir(public_bbox_dir) || isempty(readdir(public_bbox_dir)) ) || return 

    if isfile(joinpath(public_bbox_dir, "commit.json"))
        @warn "A commit shall not be within a public ballotbox before it is made public."
    end

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


function entropy_process_loop(uuid)
    
    bbox = get(POLLING_STATION, uuid) 

    if isnothing(bbox.commit)

        spec = bbox.ledger.spec
        _seed = Model.digest(rand(UInt8, 16), Model.hasher(spec))
        Controllers.set_seed!(bbox, _seed)
        Controllers.commit!(bbox, COLLECTOR; with_tally = false)
        store(Model.commit(bbox), uuid; public=false) # how did it work without this

    end

    return
end

# function broker_process_loop(; force = false)

#     force || wait(BRAID_BROKER_SCHEDULER)
#     # no pooling thus no false triggers are expected here

#     lock(MEMBER_LOCK)

#     try
#         _members = members(BRAID_CHAIN)
#         _braid = braid(BRAIDER_BROKER, _members) # one is selected at random from all available options
#     catch
#         retry!(BRAID_BROKER_SCHEDULER)
#     finally
#         unlock(MEMBER_LOCK)
#     end

#     Controllers.record!(BRAID_CHAIN, _braid)
#     Controllers.commit!(BRAID_CHAIN, RECORDER[])

#     return
# end

function tally_process_loop(uuid)

    tally_votes!(uuid; public=true)

    return
end

function reset_system()

    isdefined(@__MODULE__, :ENTROPY_SCHEDULER) && close(ENTROPY_SCHEDULER)
    isdefined(@__MODULE__, :TALLY_SCHEDULER) && close(TALLY_SCHEDULER)

    global BRAID_CHAIN = nothing # The braidchain needs to be loaded within a setup
    global POLLING_STATION = nothing
    global RECORDER = nothing
    global REGISTRAR = nothing
    global BRAIDER = nothing
    global PROPOSER = nothing
    global COLLECTOR = nothing

    return
end

function load_registrar_token(registrar::Signer)

    if haskey(ENV, "REGISTRAR_TOKEN")
        @info "Using environemnt registrar token key"
        hmac_key = ENV["REGISTRAR_TOKEN"] |> bytes2hex
    elseif isfile("/run/secrets/registrar_token") # consider adding && isfile("/run/.containerenv")
        @info "Loading registrar token from /run/secrets/registrar_token"
        hmac_key = read("/run/secrets/registrar_token") |> bytes2hex
    else
        @info "Computing registrar token deterministaclly from the private key"
        hmac_key = Model.bytes(Model.digest(Vector{UInt8}(string(registrar.key)), registrar.spec)) # 
    end

    return hmac_key
end

# Note that preferences would be stored and loaded by PeaceFounderAdmin instead
# It could make sense to make data_dir as keyword argument
function load_system() # a kwarg could be passed on whether to audit the system

    reset_system()

    @assert !isempty(readdir(DATA_DIR)) "State can't be loaded, data direcotry is empty."

    # The auditing shall only concern itself by evaluating a treehash of the ledger and comparing that with the commit
    # that can in fact be better done within the BraidChainController constructor!

    chain_ledger = Store.load(joinpath(DATA_DIR, "public", "braidchain"))
    chain_commit = load_chain_commit()
    
    global BRAID_CHAIN = BraidChainController(chain_ledger, commit = chain_commit)

    # I should iterate over all BRAID_CHAIN records and find a proposal
    
    global POLLING_STATION = PollingStation()
    global TALLY_SCHEDULER = SchedulerActor(tally_process_loop, UUID, retry_interval = 5)
    global ENTROPY_SCHEDULER = SchedulerActor(entropy_process_loop, UUID, retry_interval = 1)

    global RECORDER = load_signer(:recorder)
    
    registrar = load_signer(:registrar)
    hmac_key = load_registrar_token(registrar)

    global REGISTRAR = Registrar(registrar, hmac_key)
    Controllers.set_demehash!(REGISTRAR, BRAID_CHAIN.spec) 

    global BRAIDER = load_signer(:braider)

    global PROPOSER = load_signer(:proposer)

    global COLLECTOR = load_signer(:collector)


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
            
            Controllers.init!(POLLING_STATION, bbox)
            
            if !isnothing(COLLECTOR)
                # Checking that COLLECTOR matches that of the proposal is needed when it can change
                # Also multiple keys can be kept simultenously and thus COLLECTOR would be more like an vector
                Schedulers.schedule!(ENTROPY_SCHEDULER, proposal.open, proposal.uuid)
                Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)
            end
        end
    end

    return authorized_roles(BRAID_CHAIN.spec)
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
    if isnothing(BRAID_CHAIN)
        global BRAID_CHAIN = BraidChainController(demespec)
    end

    if !isempty(DATA_DIR)
        Store.save(BRAID_CHAIN.ledger, joinpath(DATA_DIR, "public",  "braidchain"))
    end

    if isnothing(POLLING_STATION)
        global POLLING_STATION = PollingStation()
    end

    N = findfirst(x->x==demespec.recorder, pseudonym_list)
    if !isnothing(N)
        global RECORDER = Signer(demespec.crypto, generator, key_list[N])
        store(RECORDER, :recorder)
        
        N = Controllers.record!(BRAID_CHAIN, demespec)
        store(demespec, N)
        Controllers.commit!(BRAID_CHAIN, RECORDER) 
        store(Model.commit(BRAID_CHAIN))

        global BRAID_BROKER_PROCESS = @async while true
            broker_process_loop()
        end
    end
    
    N = findfirst(x->x==demespec.registrar, pseudonym_list)
    if !isnothing(N)
        signer = Signer(demespec.crypto, generator, key_list[N])
        store(signer, :registrar)

        hmac_key = load_registrar_token(signer)

        global REGISTRAR = Registrar(signer, hmac_key)
        Controllers.set_demehash!(REGISTRAR, demespec) 
    end

    N = findfirst(x->x==demespec.braider, pseudonym_list)
    if !isnothing(N)
        global BRAIDER = Signer(demespec.crypto, generator, key_list[N])
        store(BRAIDER, :braider)
    end

    N = findfirst(x->x==demespec.proposer, pseudonym_list)
    if !isnothing(N)
        global PROPOSER = Signer(demespec.crypto, generator, key_list[N])
        store(PROPOSER, :proposer)
    end    

    N = findfirst(x->x==demespec.collector, pseudonym_list)
    if !isnothing(N)
        global COLLECTOR = Signer(demespec.crypto, generator, key_list[N])
        store(COLLECTOR, :collector)

        # I may create SchedulerActor and constructors here EntropyActor, TallyActor
        # to make the process more streamlined
        global ENTROPY_SCHEDULER = SchedulerActor(entropy_process_loop, UUID, retry_interval = 1)

        # global ENTROPY_PROCESS = Task() do
        #     while true
        #         entropy_process_loop()
        #     end
        # end
        # yield(ENTROPY_PROCESS)
        global TALLY_SCHEDULER = SchedulerActor(tally_process_loop, UUID, retry_interval = 5)
        
        # global TALLY_PROCESS = Task() do
        #     while true
        #         tally_process_loop()
        #     end
        # end
        # yield(TALLY_PROCESS)
    end    

    return authorized_roles(demespec) # I may deprecate this in favour of a method.
end

function authorized_roles(demespec::DemeSpec)

    roles = []

    if !isnothing(RECORDER) && id(RECORDER) == demespec.recorder
        push!(roles, :recorder)
    end

    if !isnothing(REGISTRAR) && id(REGISTRAR) == demespec.registrar
        push!(roles, :registrar)
    end

    if !isnothing(BRAIDER) && id(BRAIDER) == demespec.braider
        push!(roles, :braider)
    end

    if !isnothing(COLLECTOR) && id(COLLECTOR) == demespec.collector
        push!(roles, :collector)
    end

    if !isnothing(PROPOSER) && id(PROPOSER) == demespec.proposer
        push!(roles, :proposer)
    end

    return roles
end


function tally_votes!(uuid::UUID; public = ispublic(uuid)) 

    if public
        try
            make_bbox_store_public(uuid) # returns if a public ballotbox directory or if the direcotry is empty
        catch err
            @warn "Failing to make balltobox with $uuid public"
            @error "ERROR: " exception=(err, catch_backtrace())
        end
    end
    
    bbox = get(POLLING_STATION, uuid)
    Controllers.commit!(bbox, COLLECTOR; with_tally = true)
    store(Model.commit(bbox), uuid; public)

    return
end

set_demehash(spec::DemeSpec) = Controllers.set_demehash!(REGISTRAR, spec)
set_route(route::Union{URI, String}) = Controllers.set_route!(REGISTRAR, route)
get_route() = REGISTRAR.route

get_recruit_key() = Model.key(REGISTRAR)

get_demespec() = BRAID_CHAIN.spec

enlist_ticket(ticketid::TicketID, timestamp::DateTime; expiration_time = nothing, reset=false) = Controllers.enlist!(REGISTRAR, ticketid, timestamp; reset)
enlist_ticket(ticketid::TicketID; expiration_time = nothing, reset=false) = enlist_ticket(ticketid, now(); expiration_time, reset)

get_ticket_ids() = Controllers.ticket_ids(REGISTRAR)

get_ticket_status(null::Function, ticketid::TicketID) = Controllers.ticket_status(get(null, REGISTRAR, ticketid))
get_ticket_admission(null::Function, ticketid::TicketID) = get(null, REGISTRAR, ticketid).admission # This is a good example for null

get_ticket(null::Function, tokenid::AbstractString) = get(null, REGISTRAR, tokenid)
get_ticket(null::Function, ticketid::TicketID) = get(null, REGISTRAR, ticketid)

function delete_ticket(null::Function, ticketid::TicketID)
    
    ticket_index = findfirst(x -> x.ticketid == ticketid, REGISTRAR.tickets) # I could use a get_index(null, collection, predicate)
    if isnothing(ticket_index)
        null()
    else
        deleteat!(Mapper.REGISTRAR.tickets, ticket_index)
    end

    return
end

token_key() = Controllers.token_key(REGISTRAR)
token_nlen() = REGISTRAR.nlen


# The benfit of refering to a single ticketid is that it is long lasting
seek_admission(id::Pseudonym, ticketid::TicketID) = Controllers.admit!(REGISTRAR, id, ticketid) 
list_admissions() = [i.admission for i in REGISTRAR.tickets]

get_chain_roll() = Controllers.roll(BRAID_CHAIN)
get_member(null::Function, id::Pseudonym) = get(null, BRAID_CHAIN, x -> x isa Membership && Model.id(x) == id)

get_chain_commit() = Model.commit(BRAID_CHAIN)

function submit_chain_record!(transaction::Transaction) 

    # Notes on concurrency
    # If braiding is in process, membership records need to be dropped;
    # Membership and Proposal records can be recorded concurently; (a lockable vector would ensure integrity)
    # Change of DemeSpec record requires shutdown of the service. I could have a semaphore to detect that 
    # and a state variable which indicates closing of the service in which case all records are dropped.
    
    N = Controllers.record!(BRAID_CHAIN, transaction)
    store(transaction, N)
    Controllers.commit!(BRAID_CHAIN, RECORDER)
    store(Model.commit(BRAID_CHAIN))

    ack = Controllers.ack_leaf(BRAID_CHAIN, N)
    return ack
end

get_chain_record(N::Int) = BRAID_CHAIN[N]
get_chain_ack_leaf(N::Int) = Controllers.ack_leaf(BRAID_CHAIN, N)
get_chain_ack_root(N::Int) = Controllers.ack_root(BRAID_CHAIN, N)

enroll_member(member::Membership) = submit_chain_record!(member)
enlist_proposal(proposal::Proposal) = submit_chain_record!(proposal)

get_roll() = Controllers.roll(BRAID_CHAIN)

get_peers() = Controllers.peers(BRAID_CHAIN)

get_constituents() = Controllers.constituents(BRAID_CHAIN)

reset_tree() = Controllers.reset_tree!(BRAID_CHAIN)

get_members(N::Int) = Model.members(BRAID_CHAIN, N)
get_members(; reset=false) = reset ? Model.roll(BRAID_CHAIN) : Model.members(BRAID_CHAIN)

get_generator(N::Int) = Model.generator(BRAID_CHAIN, N)
get_generator(; reset=false) = reset ? Model.generator(BRAID_CHAIN.spec) : Model.generator(BRAID_CHAIN)

get_chain_proposal_list() = collect(Controllers.list(Proposal, BRAID_CHAIN))

# function schedule_pulse!(uuid::UUID, timestamp, nonceid)
    
#     Model.schedule!(DEALER[], uuid, timestamp, nonceid)
#     Schedulers.schedule!(DEALER_SCHEDULER, timestamp)

#     return
# end

function submit_chain_record!(proposal::Proposal)

    N = Controllers.record!(BRAID_CHAIN, proposal)
    store(proposal, N)
    Controllers.commit!(BRAID_CHAIN, RECORDER)
    store(Model.commit(BRAID_CHAIN))

    spec = get_demespec()
    anchored_members = Model.voters(BRAID_CHAIN, proposal) # I could get a braid output_members
    Controllers.init!(POLLING_STATION, spec, proposal, anchored_members)

    init_bbox_store(Controllers.ledger(get(POLLING_STATION, proposal)))

    Schedulers.schedule!(ENTROPY_SCHEDULER, proposal.open, proposal.uuid)
    Schedulers.schedule!(TALLY_SCHEDULER, proposal.closed, proposal.uuid)

    ack = Controllers.ack_leaf(BRAID_CHAIN, N)
    return ack
end


function cast_vote(uuid::UUID, vote::Vote; late_votes = false, ctime = now())

    if !(Model.isstarted(get_proposal(uuid); time = ctime))

        error("Voting have not yet started")

    elseif !late_votes && Model.isdone(get_proposal(uuid); time = ctime)

        error("Vote received for proposal too late")
        
    else
        # Concurency can be used with a following API but it requires defining 
        # a new vector type which has a write lock.

        bbox = get(POLLING_STATION, uuid)        
        N = Controllers.record!(bbox, vote)

        # commit! may make dublicates in cases when record! executed async
        # this is not a big issue. We are mainly concerned with validating records fast
        # and selecting needles from a haystack
        Controllers.commit!(bbox, COLLECTOR)

        # the disk storage will happen with the vector, thus commit would not be anounced before
        # it would be backed by a persitent disk record.
        #public = !isnothing(bbox.commit.state.tally) # only tally_votes can make bbox public
        public = Model.istallied(bbox) # only tally_votes can make bbox public
        store(bbox[N], uuid, N; public)
        store(Model.commit(bbox), uuid; public)

        ack = Controllers.ack_cast(POLLING_STATION, uuid, N)
        return ack
    end
end

get_ballotbox(uuid::UUID) = get(POLLING_STATION, uuid)

get_proposal(uuid::UUID) = get_ballotbox(uuid).ledger.proposal
get_proposal(index::Int) =  BRAID_CHAIN[index]::Proposal

get_tally(uuid::UUID) = ballotbox(uuid).tally

get_ballotbox_commit(uuid::UUID) = Model.commit(POLLING_STATION, uuid)

get_ballotbox_ack_leaf(uuid::UUID, N::Int) = Controllers.ack_leaf(POLLING_STATION, uuid, N)
get_ballotbox_ack_root(uuid::UUID, N::Int) = Controllers.ack_root(POLLING_STATION, uuid, N)

get_ballotbox_spine(uuid::UUID) = Controllers.spine(POLLING_STATION, uuid)

function get_ballotbox_record(uuid::UUID, N::Int; fairness::Bool = true)
   
    bbox = Controllers.ballotbox(PollingStation, uuid)        
    
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        return bbox[N] # Model.record(bbox, N)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end

get_ballotbox_receipt(uuid::UUID, N::Int) = Model.receipt(POOLING_STATION, uuid, N)

get_cast_record_status(uuid::UUID, N::Int) = Model.cast_record_status(get_ballotbox(uuid), N)

# The access seems better to be dealt at the topmost level
function get_ballotbox_ledger(uuid::UUID; fairness::Bool = true, tally_trigger_delay::Union{Nothing, Int} = nothing)

    bbox = Controllers.ballotbox(PollingStation, uuid)        

    # trigger_tally!(uuid; tally_trigger_delay)
    # If fair then only when the tally is published the vote can be accessed
    if fairness && isnothing(bbox.tally) || !fairness
        Controllers.ledger(bbox)
    else
        error("Due to fairness individual votes will be available only after tallly will be committed by the collector")
    end

end


end
