# One could add expiration policy and etc. Currently that is not needed.

struct TicketID
    id::Vector{UInt8}
end

Base.:(==)(x::TicketID, y::TicketID) = x.id == y.id

TicketID(x::String) = TicketID(copy(Vector{UInt8}(x)))


struct Admission
    ticketid::TicketID # document on which basis recruiter have decided to approve the member
    id::Pseudonym
    date::Date # Note that there should be a deadline until which admission could be used
    approval::Union{Seal, Nothing}
end


Admission(ticketid::TicketID, id::Pseudonym, date::Date) = Admission(ticketid, id, date, nothing)


approve(admission::Admission, signer::Signer) = @set admission.approval = seal(admission, signer)


id(admission::Admission) = admission.id


mutable struct Ticket
    const ticketid::TicketID
    token::BigInt
    admission::Union{Admission, Nothing}
end


struct TokenRecruiter
    tickets::Vector{Ticket}
    signer::Signer
end


TokenRecruiter(signer) = TokenRecruiter(Tuple{TicketID, BigInt, Union{Admission, Nothing}}[], signer)


ticket_ids(recruiter::TokenRecruiter) = (i.ticketid for i in recruiter.tickets)

function admission(recruiter::TokenRecruiter, ticketid::TicketID)

    for i in recruiter.tickets
        if i.ticketid == ticketid
            return i.admission
        end
    end

    error("No ticket with given ticketid found")
end


Base.in(ticketid::TicketID, recruiter::TokenRecruiter) = ticketid in ticket_ids(recruiter)


function add!(recruiter::TokenRecruiter, ticketid::TicketID)
   
    for i in recruiter.tickets
        if i.ticketid == ticketid
            return i.token
        end
    end
    
    token::BigInt = rand(1:10000)
    @assert isnothing(findfirst(x -> x.token == token, recruiter.tickets))

    push!(recruiter.tickets, Ticket(ticketid, token, nothing))

    return token
end

function admit!(recruiter::TokenRecruiter, id::Pseudonym, token::BigInt)
    
    N = findfirst(x -> x.token == token, recruiter.tickets)
    isnothing(N) && error("Token not found")

    ticket = recruiter.tickets[N]

    if isnothing(ticket.admission)

        date = Date(Dates.now())
        admission_draft = Admission(ticket.ticketid, id, date)

        ticket.admission = approve(admission_draft, recruiter.signer)

    end

    return ticket.admission
end


#admissions(recruiter::TokenRecruiter) == (i[3] for i in recruiter.data if i[3] isa Admission)

# Server can simply check on token
function isadmitted(recruiter::TokenRecruiter, ticketid::TicketID)

    for a in recruiter.tickets
        if a.ticketid == ticketid
            if isnothing(a.admission)
                return false
            else
                return true
            end
        end
    end

    error("Ticket not found")
end

unpack(x::Vector) = length(x) == 0 ? nothing : x[1]
unpack(x::Nothing) = nothing


Base.getindex(recruiter::TokenRecruiter, ticketid::TicketID) = filter(x -> x.ticketid == ticketid, admissions(recruiter)) |> unpack
Base.getindex(recruiter::TokenRecruiter, id::Pseudonym) = filter(x -> x.id == id, admissions(recruiter)) |> unpack
