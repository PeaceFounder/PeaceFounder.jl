import Random
using URIs
using Base64: base64encode # for tokenid

# One could add expiration policy and etc. Currently that is not needed.

"""
    mutable struct Ticket
        const ticketid::TicketID
        timestamp::DateTime
        attempt::UInt8
        token::Digest
        tokenid::String # 
        admission::Union{Admission, Nothing}
    end

Represents a ticket state for ticket with `ticketid`. `timestamp` represents time when the ticket have been issued by a recruiter client in authorization system of choice, for instance, Recruiters.jl; `attempt` is a counter with which token can be reset which is calculated with `token(ticketid, attempt, hmac)`. Lastly `admission` contains a certified member pseudonym which was authetificated by the user with `token`.
"""
mutable struct Ticket
    const ticketid::TicketID
    timestamp::DateTime
    attempt::UInt8
    token::Vector{UInt8} # token can have a variable length to reduce space
    tokenid::String # 
    admission::Union{Admission, Nothing}
end

function Ticket(ticketid::TicketID, timestamp::DateTime, hmac::HMAC; nlen=16) 
   
    attempt::UInt8 = 0 
    _token = token(ticketid, attempt, hmac; nlen)
    _tokenid = tokenid(_token, hasher(hmac))

    return Ticket(ticketid, timestamp, attempt, _token, _tokenid, nothing)
end


function reset!(ticket::Ticket, timestamp::DateTime, hmac::HMAC; nlen=16) # nlen needs to be coupled with registrar at the Mapper level

    if timestamp < ticket.timestamp
        @warn "Ignoring old token reset request."
        return
    end

    if ticket.attempt == 255
        error("All attempts used. Create a new ticket.")
    end
    
    ticket.timestamp = timestamp
    ticket.attempt = ticket.attempt + 1
    ticket.token = token(ticket.ticketid, ticket.attempt, hmac; nlen)
    ticket.tokenid = tokenid(ticket.token, hasher(hmac))

    return
end


isadmitted(ticket::Ticket) = !isnothing(ticket.admission)

"""
    struct Registrar
        metadata::Ref{Vector{UInt8}} 
        tickets::Vector{Ticket}
        signer::Signer
        hmac::HMAC
    end

Represents a state for token recruiter service. To initialize the service it's necessary to create a signer who can issue a valid admisssion certificates and a secret key with which a recruit client can exchange authorized messages. See also method `generate(Registrar, spec)`.

Metadata is used as means to securelly deliver to the client most recent server specification. 

**Interface:** [`select`](@ref), [`hmac`](@ref), [`hasher`](@ref), [`key`](@ref), [`id`](@ref), [`tickets`](@ref), [`in`](@ref), [`set_metadata!`](@ref), [`enlist!`](@ref), [`admit!`](@ref), [`isadmitted`](@ref), [`ticket_status`](@ref)
"""
mutable struct Registrar
    demehash::Digest 
    tickets::Vector{Ticket}
    signer::Signer
    hmac::HMAC
    route::URI # A route that is included when invite is created
    nlen::Int # number of bytes for a token
end

Registrar(signer::Signer, hmac::HMAC) = Registrar(Digest(), Ticket[], signer, hmac, URI(), 8)
Registrar(signer::Signer, key::Vector{UInt8}) = Registrar(Digest(), Ticket[], signer, HMAC(key, hasher(signer)), URI(), 8)


"""
    generate(Registrar, spec::CryptoSpec)

Generate a new token recruiter with unique signer and athorization key.
"""
function generate(::Type{Registrar}, spec::CryptoSpec)

    key = rand(Random.RandomDevice(), UInt8, 32) # Alternativelly I could derive it from a global SEED
    recruiter = generate(Signer, spec)

    return Registrar(recruiter, key)
end

"""
    hmac(x)::HMAC

Return HMAC authorizer from a given object.
"""
hmac(recruiter::Registrar) = recruiter.hmac
hasher(recruiter::Registrar) = hasher(hmac(recruiter))
key(recruiter::Registrar) = key(hmac(recruiter))
id(recruiter::Registrar) = id(recruiter.signer)


"""
    select(T, predicate::Function, recruiter::Registrar)::Union{T, Nothing}

From a list of all `recruiter` tickets return `T <: Union{Ticket, Admission}` for which predicate is true. If none succeds returns nothing.
"""
function select(::Type{Ticket}, f::Function, recruiter::Registrar)
    
    for i in recruiter.tickets
        if f(i) == true
            return i
        end
    end
    
    return nothing
end

select(::Type{Ticket}, ticketid::TicketID, recruiter::Registrar) = select(Ticket, i -> i.ticketid == ticketid, recruiter)

select(::Type{Admission}, f::Function, recruiter::Registrar) = select(Ticket, f, recruiter).admission

"""
    select(Admission, ticketid::TicketID, recruiter::Registrar)::Union{Admission, Nothing}

Return admission for a ticket with given `ticketid` from `recruiter`. If no ticket with given `ticketid` is found OR ticket is not yet admitted returns nothing.
"""
select(::Type{Admission}, ticketid::TicketID, recruiter::Registrar) = select(Admission, i -> i.ticketid == ticketid, recruiter)

"""
    select(Admission, ticketid::TicketID, recruiter::Registrar)::Union{Admission, Nothing}

Return admission for a ticket with given a given identity pseudonym from `recruiter`. If no ticket with given `id` is found OR ticket is not yet admitted returns nothing.
"""
select(::Type{Admission}, id::Pseudonym, recruiter::Registrar) = select(Admission, i -> isnothing(i) ? false : i.admission.id == id, recruiter::Registrar)


select(::Type{Ticket}, tokenid::AbstractString, registrar::Registrar) = select(Ticket, i -> i.tokenid == tokenid, registrar)


ticket_ids(recruiter::Registrar) = tickets(recruiter)

"""
    tickets(recruiter::Registrar)::Vector{TicketID}

Return a list of registered ticket ids. 
"""
tickets(recruiter::Registrar) = (i.ticketid for i in recruiter.tickets)

"""
    in(ticketid::TicketID, recruiter::Registrar)::Bool

Return true if there already is a ticket with `ticketid`.
"""
Base.in(ticketid::TicketID, recruiter::Registrar) = ticketid in ticket_ids(recruiter)


using Infiltrator

"""
    token(ticketid::TicketID, hmac::HMAC)

Compute a recruit token for a given ticketid. Calculates it as `token=Hash(Hash(0|key)|attempt|ticketid)` 
where attempt is a counter for which token is issued.

Note: the token generation from key is made in order to support it's local computation on a remote server where QR code
for registration is shown within organization website.
"""
function token(ticketid::TicketID, attempt::UInt8, hash::Hash, key::Vector{UInt8}; nlen=16) 


    token_key = hash(UInt8[0, key...]) # 0 is prepended as hash(key(hmac)) is often used as keyid
    _token = hash(UInt8[bytes(token_key)..., attempt, bytes(ticketid)...])

    return bytes(_token)[1:nlen] 
end

token(ticketid::TicketID, attempt::UInt8, hmac::HMAC; nlen=16) = token(ticketid, attempt, hasher(hmac), key(hmac); nlen)

tokenid(token::Vector{UInt8}, hash::Hash) = digest(token, hash) |> bytes |> base64encode


"""
    set_demespec!(recruiter::Registrar, spec::Union{Digest, DemeSpec})

Replace metadata for a recruiter. Note when data is replaced all unfinalized tokens need to be flushed. 
"""
set_demehash!(recruiter::Registrar, spec::Digest) = recruiter.demehash = spec
set_demehash!(registrar::Registrar, spec::DemeSpec) = set_demehash!(registrar, digest(spec, hasher(spec)))

set_route!(registrar::Registrar, route::URI) = registrar.route = route
set_route!(registrar::Registrar, route::String) = set_route!(registrar, URI(route))


struct Invite
    demehash::Digest
    token::Vector{UInt8} 
    hasher::Hash # HashSpec
    route::URI
end

Base.:(==)(x::Invite, y::Invite) = x.demehash == y.demehash && x.token == y.token && x.hasher == y.hasher && x.route == y.route

# This gives a nasty error for some reason when CryptoGroups are imported.
#@batteries Invite

isbinding(spec::DemeSpec, invite::Invite) = Model.digest(spec, invite.hasher) == invite.demehash

# Parsing to string and back

hasher(invite::Invite) = invite.hasher

function enlist!(recruiter::Registrar, ticketid::TicketID, timestamp::DateTime; route::URI=recruiter.route)

    # Assertion for request is needed to be done at Service layer
    # @assert (Dates.now() - timestamp) < Second(3600) "Request too old"

    demehash = recruiter.demehash

    for ticket in recruiter.tickets
        if ticket.ticketid == ticketid
            if isadmitted(ticket)
                error("Ticket with $ticketid is already admitted.")
            else
                return Invite(demehash, ticket.token, hasher(recruiter.hmac), route)
            end
        end
    end

    ticket = Ticket(ticketid, timestamp, hmac(recruiter); nlen = recruiter.nlen)
    push!(recruiter.tickets, ticket)

    return Invite(demehash, ticket.token, hasher(recruiter.hmac), route)
end



"""
    admit!(recruiter::Registrar, id::Pseudonym, ticketid::TicketID, auth_code::Digest)::Admission

Attempt to admit an identity pseudonym `id` for ticket `ticketid` with provided authorization code. This function retrieves a ticket with given `ticketid` and uses it's recorded `token` to check whether the request is binding. In the case of success an admnission certificate is formed with provided indenty pseudonym `id` and is signed by the recruter's private key. Otherwise when either of checks fail an error is raised. In the case ticket is already addmitted, returns previously stored admission. 
"""
#function admit!(recruiter::Registrar, id::Pseudonym, ticketid::TicketID, auth_code::Digest)
function admit!(recruiter::Registrar, id::Pseudonym, ticketid::TicketID) # ticketid is the authorization
    
    N = findfirst(x -> x.ticketid == ticketid, recruiter.tickets)
    isnothing(N) && error("Ticket not found")

    ticket = recruiter.tickets[N]

    if isnothing(ticket.admission)

        admission_draft = Admission(ticket.ticketid, id, ticket.timestamp)
        ticket.admission = approve(admission_draft, recruiter.signer)
        
    end

    return ticket.admission
end

"""
    isadmitted(ticketid::TicketID, recruiter::Registrar)

Check whether a ticket is already admitted. Returns false when either ticket is nonexistent or it's admission is nothing.
"""
function isadmitted(ticketid::TicketID, recruiter::Registrar)

    admission = select(Admission, ticketid, recruiter)

    if isnothing(admission)
        return false
    else
        return true
    end
end

unpack(x::Vector) = length(x) == 0 ? nothing : x[1]
unpack(x::Nothing) = nothing


"""
struct TicketStatus
    ticketid::TicketID
    timestamp::DateTime
    admission::Union{Nothing, Admission}
end
    
Represents a public state of a ticket. See [`ticket_status`](@ref) and [`isadmitted`](@ref) methods. 
"""
struct TicketStatus
    ticketid::TicketID
    timestamp::DateTime
    admission::Union{Nothing, Admission}
end

"""
    ticket_status(ticketid::TicketID, recruiter::Registrar)::Union{TicketStatus, Nothing}

Return a ticket status for a ticketid. In case ticket is not found return nothing.
"""
function ticket_status(ticketid::TicketID, recruiter::Registrar)

    ticket = select(Ticket, ticketid, recruiter)
    
    if isnothing(ticket)
        return nothing
    else
        return TicketStatus(ticketid, ticket.timestamp, ticket.admission)
    end
end

"""
    isadmitted(status::TicketStatus)

Check whether ticket is addmitted. 
"""
isadmitted(status::TicketStatus) = !isnothing(status.admission)
