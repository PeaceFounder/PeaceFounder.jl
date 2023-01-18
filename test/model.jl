using Dates
using Test
import Sockets
import PeaceFounder.Model

import .Model: Crypto, gen_signer, pseudonym, BraidChain, commit!, TokenRecruiter, PollingStation, TicketID, add!, id, admit!, commit, verify, generator, Member, approve, record!, ack_leaf, isbinding, roll, constituents, members, state, Proposal, vote, Ballot, Selection, uuid, record, spine, tally, BeaconClient, Dealer, charge_nonces!, pulse_timestamp, nonce_promise, schedule!, next_job, pass!, draw, seed, set_seed!, ack_cast, hasher, HMAC, enlist!, token, auth


crypto = Crypto("SHA-256", "MODP", UInt8[1, 2, 3, 6])
GUARDIAN = gen_signer(crypto)

BRAID_CHAIN = BraidChain(id(GUARDIAN), crypto)
# The commitment could be on a zero state
# an alternative is making the first transaction a Manifest
commit!(BRAID_CHAIN, GUARDIAN)

RECRUIT_AUTHORIZATION_KEY = UInt8[1, 2, 3, 6, 7, 8]
RECRUIT_HMAC = HMAC(RECRUIT_AUTHORIZATION_KEY, hasher(crypto))
RECRUITER = TokenRecruiter(GUARDIAN, RECRUIT_AUTHORIZATION_KEY)

POLLING_STATION = PollingStation(crypto)

beacon = BeaconClient(id(gen_signer(crypto)), crypto, Sockets.ip"0.0.0.0")
DEALER = Dealer(crypto, beacon; delay = 5)

promises = charge_nonces!(DEALER, 100)
record!(BRAID_CHAIN, promises)

# If there are no elements in the chain this errors. 
# as well as asking for a root, leaf elements.

function enroll(signer, ticketid, token)

    auth_code = auth(id(signer), token, hasher(signer))

    # ---- evesdropers listening --------

    admission = admit!(RECRUITER, id(signer), ticketid, auth_code)
    @test verify(admission, crypto)
    _commit = commit(BRAID_CHAIN)
    @test id(_commit) == id(GUARDIAN)
    @test verify(_commit, crypto)
    g = generator(_commit)
    access = approve(Member(admission, g, pseudonym(signer, g)), signer)
    N = record!(BRAID_CHAIN, access)
    commit!(BRAID_CHAIN, GUARDIAN)
    ack = ack_leaf(BRAID_CHAIN, N)
    
    return access, ack
end

function enlist(ticketid)

    timestamp = Dates.now()
    ticket_auth_code = auth(ticketid, timestamp, RECRUIT_HMAC)

    # ---- evesdropers listening --------
    
    salt, salt_auth_code = enlist!(RECRUITER, ticketid, timestamp, ticket_auth_code) # ouptut is sent to main server    

    # ---- evesdropers listening --------
    
    @test isbinding(ticketid, salt, salt_auth_code, RECRUIT_HMAC)  # done on the server
    return token(ticketid, salt, RECRUIT_HMAC)    
end


ticketid_alice = TicketID("Alice")
token_alice = enlist(ticketid_alice)

ticketid_bob = TicketID("Bob")
token_bob = enlist(ticketid_bob)

ticketid_eve = TicketID("Eve")
token_eve = enlist(ticketid_eve)

alice = gen_signer(crypto)
access, ack = enroll(alice, ticketid_alice, token_alice)

@test isbinding(access, ack, crypto) # true if acknolwedgemnt is a witness for access; perhaps iswitness could be a better one
@test id(ack) == id(GUARDIAN)
@test verify(ack, crypto)

# At this point 
@test id(access) == id(alice)
@test pseudonym(access) == pseudonym(alice, generator(access))
@test verify(access, crypto)

# That hash of ack coreponds to one of access
@test access in roll(BRAID_CHAIN)
@test id(access) in constituents(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)


bob = gen_signer(crypto)
access, ack = enroll(bob, ticketid_bob, token_bob)

eve = gen_signer(crypto)
access, ack = enroll(eve, ticketid_eve, token_eve)

### Now I have a three members

@test access in roll(BRAID_CHAIN) # coresponds to enroll!
@test id(access) in constituents(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)

# A proposal can be constructed as

c = commit(BRAID_CHAIN)
@test verify(c, crypto)

proposal_draft = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = now(),
    closed = now() + Second(5),
    #open = Date("2020-01-01", "yyy-mm-dd"),
    #closed = Date("2020-01-02", "yyy-mm-dd"),
    collector = id(GUARDIAN),

    state = state(c)
)


proposal = approve(proposal_draft, GUARDIAN)

# I could also improve matters here
N = record!(BRAID_CHAIN, proposal)
commit!(BRAID_CHAIN, GUARDIAN)
ack = ack_leaf(BRAID_CHAIN, N)

@test isbinding(proposal, ack, crypto)
@test id(ack) == id(GUARDIAN)
@test verify(ack, crypto)

timestamp = pulse_timestamp(BRAID_CHAIN, proposal.uuid)
nonceid = nonce_promise(BRAID_CHAIN, proposal.uuid)

schedule!(DEALER, proposal.uuid, timestamp, nonceid)

add!(POLLING_STATION, proposal, members(BRAID_CHAIN, proposal))

@test isready(DEALER)

job = next_job(DEALER)

pass!(DEALER, job.uuid)
lot = draw(DEALER, job.uuid)
record!(BRAID_CHAIN, lot)

_seed = seed(lot) # method needs to be stable
set_seed!(POLLING_STATION, job.uuid, _seed)

v = vote(proposal, _seed, Selection(2), alice)
N = record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), GUARDIAN)

@test verify(commit(POLLING_STATION, uuid(proposal)), crypto)

#ack = ack_leaf(POLLING_STATION, uuid(proposal), N)
ack = ack_cast(POLLING_STATION, uuid(proposal), N)

@test isbinding(v, ack, crypto)
@test id(ack) == id(GUARDIAN)
@test verify(ack, crypto)

v = vote(proposal, _seed, Selection(1), bob)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), GUARDIAN)

v = vote(proposal, _seed, Selection(2), eve)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), GUARDIAN)


_record = record(POLLING_STATION, uuid(proposal), 3)
@test _record.vote == v
@test isbinding(_record, spine(POLLING_STATION, uuid(proposal)), crypto)

r = tally(POLLING_STATION, uuid(proposal)) 

commit!(POLLING_STATION, uuid(proposal), GUARDIAN; with_tally = true) 
