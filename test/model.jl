using Dates
using Test
import PeaceFounder.Model

import .Model: CryptoSpec, pseudonym, BraidChain, commit!, Registrar, PollingStation, TicketID, add!, id, admit!, commit, verify, generator, Membership, approve, record!, ack_leaf, isbinding, roll, constituents, members, state, Proposal, vote, Ballot, Selection, uuid, record, spine, tally, seed, set_seed!, ack_cast, hasher, HMAC, enlist!, DemeSpec, generate, Signer, key, braid, Model, set_demehash!, Ticket, tokenid, select, digest, voters

crypto = CryptoSpec("sha256", "EC: P_192")
#crypto = CryptoSpec("sha256", "EC: P-192")
#crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

GUARDIAN = generate(Signer, crypto)
PROPOSER = generate(Signer, crypto)
COLLECTOR = generate(Signer, crypto)

REGISTRAR = generate(Registrar, crypto)
BRAIDER = generate(Signer, crypto)

BRAID_CHAIN_RECORDER = generate(Signer, crypto)

demespec = DemeSpec(;
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    crypto = crypto,
                    guardian = id(GUARDIAN),
                    recorder = id(BRAID_CHAIN_RECORDER),
                    registrar = id(REGISTRAR),
                    braider = id(BRAIDER),
                    proposer = id(PROPOSER),
                    collector = id(COLLECTOR)
) |> approve(PROPOSER) 


BRAID_CHAIN = BraidChain(demespec)
record!(BRAID_CHAIN, demespec)

commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
set_demehash!(REGISTRAR, demespec)

POLLING_STATION = PollingStation(crypto)


function enroll(signer, invite)

    # The authorization is being put within a service layer which exposes the API

    _tokenid = tokenid(invite.token, invite.hasher)
    ticket = select(Ticket, _tokenid, REGISTRAR)

    admission = admit!(REGISTRAR, id(signer), ticket.ticketid) #, auth_code)

    @test verify(admission, crypto)
    _commit = commit(BRAID_CHAIN)
    @test id(_commit) == id(BRAID_CHAIN_RECORDER)
    @test verify(_commit, crypto)
    g = generator(_commit)
    access = approve(Membership(admission, g, pseudonym(signer, g)), signer)
    N = record!(BRAID_CHAIN, access)

    commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
    ack = ack_leaf(BRAID_CHAIN, N)
    
    return access, ack
end


enlist(ticketid) = enlist!(REGISTRAR, ticketid, Dates.now())


ticketid_alice = TicketID("Alice")
invite_alice = enlist(ticketid_alice)

ticketid_bob = TicketID("Bob")
invite_bob = enlist(ticketid_bob)

ticketid_eve = TicketID("Eve")
invite_eve = enlist(ticketid_eve)

#alice = generate(Signer, crypto)
alice = Signer(crypto, 2)
access, ack = enroll(alice, invite_alice)

@test isbinding(access, ack, crypto) # true if acknolwedgemnt is a witness for access; perhaps iswitness could be a better one
@test id(ack) == id(BRAID_CHAIN_RECORDER)
@test verify(ack, crypto)

# At this point 
@test id(access) == id(alice)
@test pseudonym(access) == pseudonym(alice, generator(access))
@test verify(access, crypto)

# That hash of ack coreponds to one of access
@test access in roll(BRAID_CHAIN)
@test id(access) in constituents(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)

#bob = generate(Signer, crypto)
bob = Signer(crypto, 3)
access, ack = enroll(bob, invite_bob)

#eve = generate(Signer, crypto)
eve = Signer(crypto, 4)
access, ack = enroll(eve, invite_eve)

### Now I have a three members

@test access in roll(BRAID_CHAIN) # coresponds to enroll!
@test id(access) in constituents(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)


# Here now can a braiding happen

input_generator = generator(BRAID_CHAIN)
input_members = members(BRAID_CHAIN)

braidwork = braid(input_generator, input_members, demespec, demespec, BRAIDER) 

@test Model.input_generator(braidwork) == generator(BRAID_CHAIN) 
@test Set(Model.input_members(braidwork)) == members(BRAID_CHAIN)

@test verify(braidwork, crypto)

record!(BRAID_CHAIN, braidwork)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

@test Model.output_generator(braidwork) == generator(BRAID_CHAIN)
@test Set(Model.output_members(braidwork)) == members(BRAID_CHAIN)

@test generator(BRAID_CHAIN, length(BRAID_CHAIN) - 1) == Model.input_generator(braidwork)
@test generator(BRAID_CHAIN, length(BRAID_CHAIN)) == Model.output_generator(braidwork)


# A proposal can be constructed as

c = commit(BRAID_CHAIN)
@test verify(c, crypto)

proposal = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = now(),
    closed = now() + Second(5),
    collector = demespec.collector,
    state = state(c)
) |> approve(PROPOSER)


N = record!(BRAID_CHAIN, proposal)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
ack = ack_leaf(BRAID_CHAIN, N)

@test isbinding(proposal, ack, crypto)
@test id(ack) == id(BRAID_CHAIN_RECORDER)
@test verify(ack, crypto)

#add!(POLLING_STATION, proposal, members(BRAID_CHAIN, proposal))
add!(POLLING_STATION, proposal, voters(BRAID_CHAIN, proposal))

# Ideally the seed would be a Pulse from the League of Entropy
_seed = digest(rand(UInt8, 16), hasher(demespec))
set_seed!(POLLING_STATION, proposal.uuid, _seed)
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)

v = vote(proposal, _seed, Selection(2), alice)
N = record!(POLLING_STATION, uuid(proposal), v) # This should have failed
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)

@test verify(commit(POLLING_STATION, uuid(proposal)), crypto)

ack = ack_cast(POLLING_STATION, uuid(proposal), N)

@test isbinding(v, ack, crypto)
@test id(ack) == id(COLLECTOR)
@test verify(ack, crypto)

v = vote(proposal, _seed, Selection(1), bob)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)

v = vote(proposal, _seed, Selection(2), eve)
record!(POLLING_STATION, uuid(proposal), v)
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)


_record = record(POLLING_STATION, uuid(proposal), 3)
@test _record.vote == v
@test isbinding(_record, spine(POLLING_STATION, uuid(proposal)), crypto)

r = tally(POLLING_STATION, uuid(proposal)) 

commit!(POLLING_STATION, uuid(proposal), COLLECTOR; with_tally = true) 
