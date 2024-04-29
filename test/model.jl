using Test

using Dates
using PeaceFounder.Core: Model
using PeaceFounder.Server: Controllers

import .Model: CryptoSpec, pseudonym, TicketID, id, commit, verify, generator, Membership, Termination, approve, isbinding, Proposal, vote, Ballot, Selection, uuid, tally, seed, hasher, HMAC, DemeSpec, generate, Signer, key, braid, Model, select, digest, voters, members, root, audit, roll, blacklist, termination_bitmask

import .Controllers: Registrar, admit!, enlist!, set_demehash!, Ticket, tokenid
import .Controllers: record!, commit!, ack_leaf
import .Controllers: BraidChainController, state, ledger
import .Controllers: BallotBoxController, PollingStation, init!, ack_cast, set_seed!, spine


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
                    uuid = Base.UUID(rand(UInt128)),
                    title = "A local democratic communituy",
                    email = "guardian@peacefounder.org",
                    crypto = crypto,
                    recorder = id(BRAID_CHAIN_RECORDER),
                    registrar = id(REGISTRAR),
                    braider = id(BRAIDER),
                    proposer = id(PROPOSER),
                    collector = id(COLLECTOR)
) |> approve(GUARDIAN) 


BRAID_CHAIN = BraidChainController(demespec)
record!(BRAID_CHAIN, demespec)

commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
set_demehash!(REGISTRAR, demespec)

#POLLING_STATION = PollingStation(crypto)
POLLING_STATION = PollingStation()


function enroll(signer, invite)

    # The authorization is being put within a service layer which exposes the API

    _tokenid = tokenid(invite.token, invite.hasher)
    ticket = get(REGISTRAR, _tokenid) do
        error("Ticket with $_tokenid not found")
    end

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

enlist(ticketid) = enlist!(REGISTRAR, ticketid, Dates.now(UTC))

ticketid_alice = TicketID("Alice")
invite_alice = enlist(ticketid_alice)

ticketid_bob = TicketID("Bob")
invite_bob = enlist(ticketid_bob)

ticketid_david = TicketID("Dilan")
invite_david = enlist(ticketid_david)

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
@test id(access) in roll(BRAID_CHAIN) 
@test pseudonym(access) in members(BRAID_CHAIN)

bob = Signer(crypto, 3)
access, ack = enroll(bob, invite_bob)

david = Signer(crypto, 5)
david_access, david_ack = enroll(david, invite_david)

eve = Signer(crypto, 4)
access, ack = enroll(eve, invite_eve)

### Now I have a three members

@test id(access) in roll(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)

# Here now can a braiding happen

input_generator = generator(BRAID_CHAIN)
input_members = members(BRAID_CHAIN)

braidwork = braid(input_generator, input_members, demespec.crypto, demespec, BRAIDER) 

@test Model.input_generator(braidwork) == generator(BRAID_CHAIN) 
@test Set(Model.input_members(braidwork)) == members(BRAID_CHAIN)

@test verify(braidwork, crypto)

record!(BRAID_CHAIN, braidwork)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

@test Model.output_generator(braidwork) == generator(BRAID_CHAIN)
@test Set(Model.output_members(braidwork)) == members(BRAID_CHAIN)

@test generator(BRAID_CHAIN, length(BRAID_CHAIN) - 1) == Model.input_generator(braidwork)
@test generator(BRAID_CHAIN, length(BRAID_CHAIN)) == Model.output_generator(braidwork)

# Termination of registration process after issued admission

ticketid_fiona = TicketID("Fiona")
invite_fiona = enlist(ticketid_fiona)
fiona = Signer(crypto, 6)
ticket = get(REGISTRAR, tokenid(invite_fiona.token, invite_fiona.hasher)) do
    error("Ticket for Fiona not found ")
end
admission = admit!(REGISTRAR, id(fiona), ticket.ticketid)

termination = Termination(id(admission)) |> approve(REGISTRAR.signer)
record!(BRAID_CHAIN, termination)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

g = generator(BRAID_CHAIN)
access = Membership(admission, g, pseudonym(fiona, g)) |> approve(fiona)
@test_throws AssertionError record!(BRAID_CHAIN, access)

# Imediate termination after registration

ticketid_lucy = TicketID("Lucy")
invite_lucy = enlist(ticketid_lucy)
lucy = Signer(crypto, 7)
lucy_access, lucy_ack = enroll(lucy, invite_lucy)

@test id(lucy) in roll(BRAID_CHAIN)
@test pseudonym(lucy, BRAID_CHAIN.generator) in members(BRAID_CHAIN)

termination = Termination(Model.index(lucy_ack), id(lucy)) |> approve(REGISTRAR.signer)
record!(BRAID_CHAIN, termination)

@test !(id(lucy) in roll(BRAID_CHAIN))
@test !(pseudonym(lucy, BRAID_CHAIN.generator) in members(BRAID_CHAIN)) # reverse needs to be true

# Termination with braid reset

N = Model.index(david_ack)
david_id = id(david_access)
david_pseudonym = pseudonym(david, BRAID_CHAIN.generator)

@test david_id in roll(BRAID_CHAIN)

@test state(BRAID_CHAIN).member_count == 4

termination = Termination(david_id) |> approve(REGISTRAR.signer)
@test_throws AssertionError record!(BRAID_CHAIN, termination)

termination = Termination(N, david_id) |> approve(REGISTRAR.signer)
record!(BRAID_CHAIN, termination)

@test_throws AssertionError record!(BRAID_CHAIN, termination)

@test state(BRAID_CHAIN).member_count == 3
@test !(david_id in roll(BRAID_CHAIN))
@test david_id in blacklist(BRAID_CHAIN)
@test termination_bitmask(BRAID_CHAIN)[N]
@test pseudonym(david, BRAID_CHAIN.generator) in members(BRAID_CHAIN)

braidwork = braid(generator(BRAID_CHAIN), members(BRAID_CHAIN), demespec.crypto, demespec, BRAIDER; reset = false) 
record!(BRAID_CHAIN, braidwork)

braidwork = braid(generator(BRAID_CHAIN.spec), roll(BRAID_CHAIN), demespec.crypto, demespec, BRAIDER; reset = true) 
record!(BRAID_CHAIN, braidwork)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

@test !(pseudonym(david, BRAID_CHAIN.generator) in members(BRAID_CHAIN))

# A proposal can be constructed as

c = commit(BRAID_CHAIN)
@test verify(c, crypto)

proposal = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = now(UTC),
    closed = now(UTC) + Second(5),
    collector = demespec.collector,
    state = state(c)
) |> approve(PROPOSER)


N = record!(BRAID_CHAIN, proposal)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
ack = ack_leaf(BRAID_CHAIN, N)

@test isbinding(proposal, ack, crypto)
@test id(ack) == id(BRAID_CHAIN_RECORDER)
@test verify(ack, crypto)

init!(POLLING_STATION, demespec, proposal, voters(BRAID_CHAIN, proposal))

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

_record = get(POLLING_STATION, uuid(proposal))[3]
@test _record.vote == v
@test isbinding(_record, spine(POLLING_STATION, uuid(proposal)), crypto)

r = tally(POLLING_STATION, uuid(proposal)) 

commit!(POLLING_STATION, uuid(proposal), COLLECTOR; with_tally = true) 

# Testing ledger input output

reloaded_chain = BraidChainController(ledger(BRAID_CHAIN))

@test reloaded_chain.generator == BRAID_CHAIN.generator
@test reloaded_chain.members == BRAID_CHAIN.members
@test reloaded_chain.spec == BRAID_CHAIN.spec
@test root(reloaded_chain.tree) == root(BRAID_CHAIN.tree)

# testing bbox

bbox = get(POLLING_STATION, proposal)
_voters = voters(ledger(BRAID_CHAIN), proposal)
reloaded_bbox = BallotBoxController(ledger(bbox), _voters)

@test root(reloaded_bbox.tree) == root(bbox.tree)

# Ledger auditing

@test root(ledger(BRAID_CHAIN)) == root(BRAID_CHAIN)
@test audit(ledger(BRAID_CHAIN))
@test isbinding(ledger(BRAID_CHAIN), BRAID_CHAIN.commit)

@test isbinding(ledger(BRAID_CHAIN), ledger(bbox))
@test isbinding(ledger(bbox), bbox.commit)

@test audit(ledger(bbox))

@test audit(ledger(BRAID_CHAIN), ledger(bbox), bbox.commit)
@test audit(ledger(BRAID_CHAIN), ledger(bbox), bbox.commit.state.root)
