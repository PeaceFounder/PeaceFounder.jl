#module RegistrarController

import Random
using URIs
using Base64: base64encode # for tokenid
using Dates: DateTime

using ..Core.Model: TicketID, Admission, HMAC, Digest, DemeSpec, HashSpec, Pseudonym, Signer, CryptoSpec, digest, bytes, approve

import ..Core.Model: id, hasher, generate, key, select, isbinding
import ..Core.ProtocolSchema: isadmitted, tokenid, Invite, TicketStatus # reexporting

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

Represents a ticket state for ticket with `ticketid`. `timestamp` represents time when the ticket have been issued by a registrar client in authorization system of choice, for instance, Registrars.jl; `attempt` is a counter with which token can be reset which is calculated with `token(ticketid, attempt, hmac)`. Lastly `admission` contains a certified member pseudonym which was authetificated by the user with `token`.
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


function reset!(ticket::Ticket, timestamp::DateTime, hmac::HMAC; nlen=length(ticket.token)) # nlen needs to be coupled with registrar at the Mapper level

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

ticket_status(ticket::Ticket) = TicketStatus(ticket.ticketid, ticket.timestamp, ticket.admission)

"""
    struct Registrar
        metadata::Ref{Vector{UInt8}} 
        tickets::Vector{Ticket}
        signer::Signer
        hmac::HMAC
    end

Represents a state for token registrar service. To initialize the service it's necessary to create a signer who can issue a valid admisssion certificates and a secret key with which a recruit client can exchange authorized messages. See also method `generate(Registrar, spec)`.

Metadata is used as means to securelly deliver to the client most recent server specification. 

**Interface:** [`hmac`](@ref), [`hasher`](@ref), [`key`](@ref), [`id`](@ref), [`tickets`](@ref), [`in`](@ref), [`enlist!`](@ref), [`admit!`](@ref), [`isadmitted`](@ref)
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

Generate a new token registrar with unique signer and athorization key.
"""
function generate(::Type{Registrar}, spec::CryptoSpec)

    key = rand(Random.RandomDevice(), UInt8, 32) # Alternativelly I could derive it from a global SEED
    registrar = generate(Signer, spec)

    return Registrar(registrar, key)
end

"""
    hmac(x)::HMAC

Return HMAC authorizer from a given object.
"""
hmac(registrar::Registrar) = registrar.hmac
hasher(registrar::Registrar) = hasher(hmac(registrar))
key(registrar::Registrar) = key(hmac(registrar))
id(registrar::Registrar) = id(registrar.signer)


function Base.get(null::Function, registrar::Registrar, predicate::Function)
    
    for i in registrar.tickets
        if predicate(i) 
            return i
        end
    end

    return null()
end

Base.get(null::Function, registrar::Registrar, ticketid::TicketID) = get(null, registrar, x -> x.ticketid == ticketid)
Base.get(null::Function, registrar::Registrar, identity::Pseudonym) = get(null, registrar, x -> isnothing(x.admission) ? false : id(x.admission) == identity)
Base.get(null::Function, registrar::Registrar, tokenid::AbstractString) = get(null, registrar, x -> x.tokenid == tokenid)

ticket_ids(registrar::Registrar) = tickets(registrar)

"""
    tickets(registrar::Registrar)::Vector{TicketID}

Return a list of registered ticket ids. 
"""
tickets(registrar::Registrar) = (i.ticketid for i in registrar.tickets)

"""
    in(ticketid::TicketID, registrar::Registrar)::Bool

Return true if there already is a ticket with `ticketid`.
"""
Base.in(ticketid::TicketID, registrar::Registrar) = ticketid in ticket_ids(registrar)

"""
    token(ticketid::TicketID, hmac::HMAC)

Compute a recruit token for a given ticketid. Calculates it as `token=Hash(Hash(0|key)|attempt|ticketid)` 
where attempt is a counter for which token is issued.

Note: the token generation from key is made in order to support it's local computation on a remote server where QR code
for registration is shown within organization website.
"""
function token(ticketid::TicketID, attempt::UInt8, hash::HashSpec, token_key::Vector{UInt8}; nlen=16) 
    _token = hash(UInt8[token_key..., attempt, bytes(ticketid)...])
    return _token[1:nlen]
end

# function token_key(hmac::HMAC) 
#     hash = hasher(hmac)
#     return hash(UInt8[0, key(hmac)...])
# end    

# TODO: need to investigate why I made it so difficult and not simple
# token=Hash(token_key|attempt|ticketid)
token_key(hmac::HMAC) = key(hmac)

token_key(registrar::Registrar) = token_key(registrar.hmac)

token(ticketid::TicketID, attempt::UInt8, hmac::HMAC; nlen=16) = token(ticketid, attempt, hasher(hmac), token_key(hmac); nlen)


"""
    set_demespec!(registrar::Registrar, spec::Union{Digest, DemeSpec})

Replace metadata for a registrar. Note when data is replaced all unfinalized tokens need to be flushed. 
"""
set_demehash!(registrar::Registrar, spec::Digest) = registrar.demehash = spec
set_demehash!(registrar::Registrar, spec::DemeSpec) = set_demehash!(registrar, digest(spec, hasher(spec)))

set_route!(registrar::Registrar, route::URI) = registrar.route = route
set_route!(registrar::Registrar, route::String) = set_route!(registrar, URI(route))


"""
    enlist!(registrar::Registrar, ticketid::TicketID, timestamp::DateTime; route::URI=registrar.route)::Invite

Registers a new ticket with given `TicketID` and returns an invite. If ticket is already registered the same invite is returned.
Throws an error when ticket is already registered.
"""
function enlist!(registrar::Registrar, ticketid::TicketID, timestamp::DateTime; route::URI=registrar.route, reset::Bool=false)

    # Assertion for request is needed to be done at Service layer
    # @assert (Dates.now() - timestamp) < Second(3600) "Request too old"

    demehash = registrar.demehash

    for ticket in registrar.tickets
        if ticket.ticketid == ticketid
            if isadmitted(ticket)
                error("Ticket with $ticketid is already admitted.")
            else
                
                if reset
                    reset!(ticket, timestamp, registrar.hmac)
                end

                return Invite(demehash, ticket.token, hasher(registrar.hmac), route)
            end
        end
    end

    ticket = Ticket(ticketid, timestamp, hmac(registrar); nlen = registrar.nlen)
    push!(registrar.tickets, ticket)

    return Invite(demehash, ticket.token, hasher(registrar.hmac), route)
end



"""
    admit!(registrar::Registrar, id::Pseudonym, ticketid::TicketID)::Admission

Attempt to admit an identity pseudonym `id` for ticket `ticketid`. Authorization is expected to happen at the service layer using provided token in the invite. If a ticket is already registered return admission if it matches the provided `id`. Otherwise throe an error.
"""
function admit!(registrar::Registrar, id::Pseudonym, ticketid::TicketID) # ticketid is the authorization
    
    # May be better 
    ticket = get(registrar, ticketid) do
        error("Ticket with $ticketid can't be found")
    end

    if isnothing(ticket.admission)

        admission_draft = Admission(ticket.ticketid, id)
        ticket.admission = approve(admission_draft, registrar.signer)
        
    else

        @assert ticket.admission.id == id "TicketID is already registered with a different identity pseudonym"

    end
    
    return ticket.admission
end

"""
    isadmitted(ticketid::TicketID, registrar::Registrar)

Check whether a ticket is already admitted. Returns false when either ticket is nonexistent or it's admission is nothing.
"""
function isadmitted(ticketid::TicketID, registrar::Registrar)

    admission = get(registrar, ticketid) do
        return nothing
    end

    if isnothing(admission)
        return false
    else
        return true
    end
end

unpack(x::Vector) = length(x) == 0 ? nothing : x[1]
unpack(x::Nothing) = nothing


#end
