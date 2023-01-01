using Dates
using Test
import Sockets
import PeaceFounder.Model

import .Model: Crypto, gen_signer, pseudonym, BraidChain, commit!, TokenRecruiter, PollingStation, TicketID, add!, id, admit!, commit, verify, generator, Member, approve, record!, ack_leaf, isbinding, roll, peers, members, state, Proposal, add!, vote, Ballot, Selection, uuid, record, spine, tally, BeaconClient, Dealer, charge_nonces!, pulse_timestamp, nonce_promise, schedule!, next_job, pass!, draw, seed, set_seed!


crypto = Crypto("SHA-256", "MODP", UInt8[1, 2, 3, 6])
GUARDIAN = gen_signer(crypto)

BRAID_CHAIN = BraidChain(id(GUARDIAN), crypto)
# The commitment could be on a zero state
# an alternative is making the first transaction a Manifest
commit!(BRAID_CHAIN, GUARDIAN)

RECRUITER = TokenRecruiter(GUARDIAN)

POLLING_STATION = PollingStation(crypto)

beacon = BeaconClient(id(gen_signer(crypto)), crypto, Sockets.ip"0.0.0.0")
DEALER = Dealer(crypto, beacon; delay = 5)

promises = charge_nonces!(DEALER, 100)
record!(BRAID_CHAIN, promises)

# If there are no elements in the chain this errors. 
# as well as asking for a root, leaf elements.

function enroll!(signer, token)

    admission = admit!(RECRUITER, id(signer), token)
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


token = add!(RECRUITER, TicketID("Alice"))
alice = gen_signer(crypto)
access, ack = enroll!(alice, token)

@test isbinding(access, ack, crypto) # true if acknolwedgemnt is a witness for access; perhaps iswitness could be a better one
@test id(ack) == id(GUARDIAN)
@test verify(ack, crypto)

# At this point 
@test id(access) == id(alice)
@test pseudonym(access) == pseudonym(alice, generator(access))
@test verify(access, crypto)

# That hash of ack coreponds to one of access
@test access in roll(BRAID_CHAIN)
@test id(access) in peers(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)


token = add!(RECRUITER, TicketID("Bob"))
bob = gen_signer(crypto)
access, ack = enroll!(bob, token)


token = add!(RECRUITER, TicketID("Eve"))
eve = gen_signer(crypto)
access, ack = enroll!(eve, token)


### Now I have a three members

@test access in roll(BRAID_CHAIN) # coresponds to enroll!
@test id(access) in peers(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)

# A proposal can be constructed as

c = commit(BRAID_CHAIN)
@test verify(c, crypto)

proposal_draft = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Are you ready for democracy?",
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

ack = ack_leaf(POLLING_STATION, uuid(proposal), N)

@test isbinding(v, ack, crypto)
@test id(ack) == id(GUARDIAN)
@test verify(ack, crypto)

v = vote(proposal, _seed, Selection(1), bob)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), GUARDIAN)

v = vote(proposal, _seed, Selection(2), eve)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), GUARDIAN)


@test record(POLLING_STATION, uuid(proposal), 3) == v
@test isbinding(v, spine(POLLING_STATION, uuid(proposal)), crypto)

r = tally(POLLING_STATION, uuid(proposal)) 

commit!(POLLING_STATION, uuid(proposal), GUARDIAN; with_tally = true) 
