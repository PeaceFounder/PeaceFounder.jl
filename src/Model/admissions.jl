# One could add expiration policy and etc. Currently that is not needed.

struct TicketID
    id::Vector{UInt8}
end


bytes(ticketid::TicketID) = ticketid.id

Base.:(==)(x::TicketID, y::TicketID) = x.id == y.id

TicketID(x::String) = TicketID(copy(Vector{UInt8}(x)))


struct Admission
    ticketid::TicketID # document on which basis recruiter have decided to approve the member
    id::Pseudonym
    timestamp::DateTime # Timestamp could be used as a deadline
    approval::Union{Seal, Nothing}
end

Admission(ticketid::TicketID, id::Pseudonym, timestamp::DateTime) = Admission(ticketid, id, timestamp, nothing)

Base.:(==)(x::Admission, y::Admission) = x.ticketid == y.ticketid && x.id == y.id && x.timestamp == y.timestamp && x.approval == y.approval

approve(admission::Admission, signer::Signer) = @set admission.approval = seal(admission, signer)

issuer(admission::Admission) = isnothing(admission.approval) ? nothing : pseudonym(admission.approval)

id(admission::Admission) = admission.id

ticket(admission::Admission) = admission.ticketid


function Base.show(io::IO, admission::Admission)
    
    println(io, "Admission:")
    println(io, "  ticket : $(string(admission.ticketid))")
    println(io, "  identity : $(string(admission.id))")
    println(io, "  timestamp : $(admission.timestamp)")
    print(io, "  issuer : $(string(issuer(admission)))")

end


mutable struct Ticket
    const ticketid::TicketID
    timestamp::DateTime
    salt::Vector{UInt8}
    auth_code::Digest
    token::Digest
    admission::Union{Admission, Nothing}
end

struct TokenRecruiter
    tickets::Vector{Ticket}
    signer::Signer
    hmac::HMAC
end

TokenRecruiter(signer::Signer, hmac::HMAC) = TokenRecruiter(Ticket[], signer, hamc)
TokenRecruiter(signer::Signer, key::Vector{UInt8}) = TokenRecruiter(Ticket[], signer, HMAC(key, hasher(signer)))


hmac(recruiter::TokenRecruiter) = recruiter.hmac
hasher(recruiter::TokenRecruiter) = hasher(hmac(recruiter))
key(recruiter::TokenRecruiter) = key(hmac(recruiter))


function select(::Type{Ticket}, f::Function, recruiter::TokenRecruiter)
    
    for i in recruiter.tickets
        if f(i) == true
            return i
        end
    end
    
    return nothing
end

select(::Type{Ticket}, ticketid::TicketID, recruiter::TokenRecruiter) = select(Ticket, i -> i.ticketid == ticketid, recruiter)

select(::Type{Admission}, f::Function, recruiter::TokenRecruiter) = select(Ticket, f, recruiter).admission

select(::Type{Admission}, ticketid::TicketID, recruiter::TokenRecruiter) = select(Admission, i -> i.ticketid == ticketid, recruiter)

select(::Type{Admission}, id::Pseudonym, recruiter::TokenRecruiter) = select(Admission, i -> isnothing(i) ? false : i.admission.id == id, recruiter::TokenRecruiter)


ticket_ids(recruiter::TokenRecruiter) = tickets(recruiter)
tickets(recruiter::TokenRecruiter) = (i.ticketid for i in recruiter.tickets)
#admission(recruiter::TokenRecruiter, ticketid::TicketID) = recruiter[ticketid].admission


Base.in(ticketid::TicketID, recruiter::TokenRecruiter) = ticketid in ticket_ids(recruiter)


# I will need to add also a date to avoid creation of old tickets

bytes(time::DateTime) = reinterpret(UInt8, [time.instant.periods.value])


auth(ticketid::TicketID, time::DateTime, hmac::HMAC) = digest(UInt8[1, bytes(ticketid)..., bytes(time)...], hmac)
auth(ticketid::TicketID, salt::Vector{UInt8}, hmac::HMAC) = digest(UInt8[2, bytes(ticketid)..., salt...], hmac)

token(ticketid::TicketID, salt::Vector{UInt8}, hmac::HMAC) = digest(UInt8[0, bytes(ticketid)..., salt...], hmac)
token(ticket::Ticket, hmac::HMAC) = token(ticket.ticketid, ticket.salt, hmac)


auth(id::Pseudonym, hmac::HMAC) = digest(bytes(id), hmac)
auth(id::Pseudonym, token::Digest, hasher::Hash) = auth(id, HMAC(bytes(token), hasher))


isbinding(ticketid::TicketID, time::DateTime, auth_code::Digest, hmac::HMAC) = auth(ticketid, time, hmac) == auth_code
isbinding(ticketid::TicketID, salt::Vector{UInt8}, auth_code::Digest, hmac::HMAC) = auth(ticketid, salt, hmac) == auth_code

isbinding(id::Pseudonym, auth_code::Digest, token::Digest, hasher::Hash) = auth(id, token, hasher) == auth_code



function enlist!(recruiter::TokenRecruiter, ticketid::TicketID, timestamp::DateTime, ticket_auth_code::Digest)
   
    @assert (Dates.now() - timestamp) < Second(60) "Old request"

    @assert isbinding(ticketid, timestamp, ticket_auth_code, hmac(recruiter)) # need to be aware of replay attack and bouncing back

    for i in recruiter.tickets
        if i.ticketid == ticketid
            return (i.salt, i.auth_code)
        end
    end
    
    salt = rand(UInt8, 16) # Needs a real random number generator
    _token = token(ticketid, salt, hmac(recruiter))
    
    salt_auth_code = auth(ticketid, salt, hmac(recruiter))

    push!(recruiter.tickets, Ticket(ticketid, timestamp, salt, salt_auth_code, _token, nothing))

    return salt, salt_auth_code
end


function admit!(recruiter::TokenRecruiter, id::Pseudonym, ticketid::TicketID, auth_code::Digest)
    
    N = findfirst(x -> x.ticketid == ticketid, recruiter.tickets)
    isnothing(N) && error("Ticket not found")

    ticket = recruiter.tickets[N]

    @assert isbinding(id, auth_code, token(ticket, hmac(recruiter)), hasher(recruiter))

    if isnothing(ticket.admission)

        admission_draft = Admission(ticket.ticketid, id, ticket.timestamp)

        ticket.admission = approve(admission_draft, recruiter.signer)

    end

    return ticket.admission
end


function isadmitted(ticketid::TicketID, recruiter::TokenRecruiter)

    admission = select(Admission, ticketid, recruiter)

    if isnothing(admission)
        return false
    else
        return true
    end
end

unpack(x::Vector) = length(x) == 0 ? nothing : x[1]
unpack(x::Nothing) = nothing



struct TicketStatus
    ticketid::TicketID
    timestamp::DateTime
    admission::Union{Nothing, Admission}
end


function ticket_status(ticketid::TicketID, recruiter::TokenRecruiter)

    ticket = select(Ticket, ticketid, recruiter)

    return TicketStatus(ticketid, ticket.timestamp, ticket.admission)
end

isadmitted(status::TicketStatus) = !isnothing(status.admission)
