using Dates

# 
struct Pulse end

# isbinding(pulse, time)
# verify(pulse, crypto)

struct BeaconClient
    id::Pseudonym
    crypto::Crypto
    source # IP address and source
end

# The pulse is verified as necessary. 
function get_pulse(beacon::BeaconClient) end
function get_pulse(beacon::BeaconClient, date::DateTime) end
function get_pulse(beacon::BeaconClient, n::Int) end



struct NonceCommitment <: Transaction
    promises::Vector{Digest}
    reset::Bool
end


function Base.show(io::IO, commitment::NonceCommitment)
    
    println(io, "NonceCommitment:")
    println(io, "  promises : $(length(commitment.promises)) entries")
    print(io, "  reset : $(commitment.reset)")

end



struct DealerJob
    uuid::UUID
    timestamp::DateTime
    nonce::Digest # retrieved imediatelly
end

struct Lot <: Transaction
    uuid::UUID
    nonce::Digest
    timestamp::DateTime
    pulse::Union{Pulse, Nothing} # In case pass! is used
end

seed(lot::Lot) = isnothing(lot.pulse) ? lot.nonce : error("TODO: pulse needs to be hashed with nonce.")


function Base.show(io::IO, lot::Lot)

    println(io, "Lot:")
    println(io, "  uuid : $(lot.uuid)")
    println(io, "  nonce : $(string(lot.nonce))")
    println(io, "  timestamp : $(lot.timestamp)")
    print(io, "  pulse : $(lot.pulse)")
    
end

struct Dealer
    nonces::Vector{Digest}
    promises::Vector{Digest}
    hasher::Hash
    beacon::BeaconClient

    jobs::Vector{DealerJob}
    lots::Vector{Lot}
    delay::Int # in seconds
end

hasher(dealer::Dealer) = dealer.hasher

Dealer(crypto, beacon; delay = 5) = Dealer(Digest[], Digest[], hasher(crypto), beacon, DealerJob[], Lot[], delay)

# timestamp could be actual time when it should be run, calculated from the proposal alone. 
function schedule!(dealer::Dealer, uuid, timestamp, nonceid) 

    n = findfirst(==(nonceid), dealer.promises)
    nonce = dealer.nonces[n]

    job = DealerJob(uuid, timestamp, nonce)

    push!(dealer.jobs, job)

    return
end



function cast!(dealer::Dealer, uuid, pulse) 
    #@assert isbinding(chain, uuid, pulse)
    #@assert verify(pulse)
    error("Not implemented")
end

function take_job!(dealer::Dealer, uuid::UUID)
    
    for (n, i) in enumerate(dealer.jobs)
        if i.uuid == uuid
            
            deleteat!(dealer.jobs, n)

            return i
        end
    end

    return
end


# make a lot without a pulse
# kills a job and puts result in the lot 
function pass!(dealer::Dealer, uuid) 
    
    job = take_job!(dealer, uuid)
    
    isnothing(job) && error("No job with given uuid found")

    (; nonce, timestamp) = job

    lot = Lot(uuid, nonce, timestamp, nothing)

    push!(dealer.lots, lot)

    return lot
end

# get a lot
function draw(dealer::Dealer, uuid) 
    
    for i in dealer.lots
        if i.uuid == uuid
            return i
        end
    end

    return
end


# reset = true is only part od nonce_commitment in order to make a resetting transaction
function charge_nonces!(dealer::Dealer, n::Int; reset = true) 

    nonces = Digest[]
    promises = Digest[]
    
    for i in 1:n

        r = rand(1:1000000)

        nonce = digest(r, hasher(dealer))
        promise = digest(nonce.data, hasher(dealer))

        push!(nonces, nonce)
        push!(promises, promise)

    end

    append!(dealer.nonces, nonces)
    append!(dealer.promises, promises)

    commitment = NonceCommitment(promises, reset)

    return commitment
end # where n is with how many values

# returns soonest scheduled job
# need to be retriggered when a new job is scheduled
function next_job(dealer::Dealer) 

    if length(dealer.jobs) == 0
        return nothing
    else
        job = dealer.jobs[1]

        for i in dealer.jobs
            if i.timestamp < job.timestamp
                job = i
            end
        end

        return job
    end
end

function Base.isready(dealer::Dealer)
    
    job = next_job(dealer)

    isnothing(job) && return false

    return job.timestamp < now()
end



# This one is run at the setup phase together with generation
record!(chain::BraidChain, promise::NonceCommitment) = push!(chain, promise)

# A task which records beacon could be scheduled. This would be part of the mapper layer.
record!(chain::BraidChain, lot::Lot) = push!(chain, lot)


function nonce_promise(chain::BraidChain, uuid::UUID) 

    nonce_id_buffer = Digest[]

    for transaction in ledger(chain)
        
        if transaction isa NonceCommitment

            if transaction.reset == true
                nonce_id_buffer = []
            end
            
            append!(nonce_id_buffer, transaction.promises)

        elseif transaction isa Proposal

            _nonce_id = popfirst!(nonce_id_buffer)

            if transaction.uuid == uuid
                return _nonce_id
            end

        end

    end

    error("proposal with given uuid not found")

end



function pulse_timestamp(chain::BraidChain, uuid::UUID) 
    _proposal = select(Proposal, uuid, chain)
    #_proposal = select(x -> x.uuid == uuid, proposals(chain))
    return _proposal.open
end 



select(::Type{Lot}, uuid::UUID, chain::BraidChain) = select(Lot, x -> x.uuid == uuid, chain)


#lot(chain::BraidChain, uuid::UUID) = select(x -> x isa Lot && x.uuid == uuid, ledger(chain))

