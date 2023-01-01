module Client
# Methods to interact with HTTP server

using ..Model
using ..Model: Member, Pseudonym, Proposal, Vote, BraidChainSummary
using HTTP: Router, Request, Response
using JSON3

using ..Model: base16encode, base16decodev



function post(target, msg; body = [])

    io = IOBuffer()
    JSON3.write(io, msg)

    req = Request("POST", target, body, take!(io))

    return req
end


function get(target; body = [])

    req = Request("GET", target, body)

    return req
end


# Parametrization with regards to type is somewhat controversial. It's not always the case for new type to be created.
post_member(router::Router, member::Member) = post("/members", member) |> router

function get_member_list(router::Router)

    resp = get("/members") |> router

    list = JSON3.read(resp.body, Vector{Tuple{String, Pseudonym}})

    return list
end



function get_member(router::Router, id::Pseudonym)
    
    resp = get("/members/" * base16encode(id)) |> router

    member = JSON3.read(resp.body, Member)

    return member
end

"""
Registers a member if possible. Possible error states:

    - server not reachable
    - invalid bare state
    - invalid admission
    - no reply from server on success (In this case member checks server on /members/{id} if registration was succesfull)
"""
function enroll_member(router::Router, admission::Admission, signer::Signer)

    summary = Client.get_braidchain_summary(ROUTER)
    # verification of the state could be added here
    @assert verify(summary.state)
    member = Member(admission, generator(summary), alice)
    newstate, oldtreehash = Client.post_member(ROUTER, member)
    @assert verify(member, oldtreehash, newstate) # 

    # Both states can be kept locally to keep the server accountable
    return
end


function get_admission(router::Router, id::Pseudonym, tooken::BigInt) end

function enroll_member(router::Router, tooken::BigInt, signer::Signer)

    admission = get_admission(router, pseudonym(signer), tooken) # could be repeated as long as tooken remains the same

    enroll_member(router::Router, admission, signer)

    return
end


function post_proposal(router::Router, proposal::Proposal) end


function get_proposals(router::Router; status=nothing) end

function get_proposal(router::Router, pid::UUID) end



function update_proposal(router::Router, proposal::Proposal) end
#function update_proposal(router::Router, proposal::Proposal, tooken::Tooken) end


function get_votes(router::Router, pid::UUID) end


function get_vote(router::Router, pid::UUID, n::Int) end # It's an authetificated chain


function post_vote(router::Router, vote::Vote) end 

function get_result(router::Router, pid::UUID) end


# Returns the length of the cahin. A tree hash as well. Number of memebers and proposals. Some other statistics.
function get_braidchain_summary(router::Router) 
    resp = get("/braidchain") |> router
    summary = JSON3.read(resp.body, BraidChainSummary)
    return summary
end 


function get_braidchain_element(router::Router, n::Int) end # This is where different Transaction types would need to be filtered out. A type field could be suitable here.


# Server methods when interacting with server. 


function get_braider_summary(router::Router) end # Available summary before athetification


function post_braider_job(req::Request, braidjob) end
#function post_braider_job(req::Request, tooken::Tooken) end

function get_braider_job_summary(router::Router) end # Note that jobs would contain entries available after authetification


function get_braider_job(router::Router, jobid::UUID) end







end
