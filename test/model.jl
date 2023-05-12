using Dates
using Test
import PeaceFounder.Model

import .Model: CryptoSpec, pseudonym, BraidChain, commit!, TokenRecruiter, PollingStation, TicketID, add!, id, admit!, commit, verify, generator, Member, approve, record!, ack_leaf, isbinding, roll, constituents, members, state, Proposal, vote, Ballot, Selection, uuid, record, spine, tally, BeaconClient, Dealer, charge_nonces!, pulse_timestamp, nonce_promise, schedule!, next_job, pass!, draw, seed, set_seed!, ack_cast, hasher, HMAC, enlist!, token, auth, DemeSpec, generate, Signer, key, braid, Model


crypto = CryptoSpec("sha256", "EC: P_192")
#crypto = CryptoSpec("sha256", "EC: P-192")
#crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

#GUARDIAN = gen_signer(crypto)
GUARDIAN = generate(Signer, crypto)
PROPOSER = generate(Signer, crypto)
COLLECTOR = generate(Signer, crypto)

RECRUITER = generate(TokenRecruiter, crypto)
RECRUIT_HMAC = HMAC(key(RECRUITER), hasher(crypto))
RECRUITER.metadata[] = UInt8[1, 2, 3, 4] # Optional

BRAIDER = generate(Signer, crypto)

BRAID_CHAIN_RECORDER = generate(Signer, crypto)


demespec = DemeSpec(;
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    crypto = crypto,
                    guardian = id(GUARDIAN),
                    recorder = id(BRAID_CHAIN_RECORDER),
                    recruiter = id(RECRUITER),
                    braider = id(BRAIDER),
                    proposer = id(PROPOSER),
                    collector = id(COLLECTOR)
) |> approve(PROPOSER) 


BRAID_CHAIN = BraidChain(demespec)

commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

POLLING_STATION = PollingStation(crypto)

DEALER = Dealer(demespec)

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
    @test id(_commit) == id(BRAID_CHAIN_RECORDER)
    @test verify(_commit, crypto)
    g = generator(_commit)
    access = approve(Member(admission, g, pseudonym(signer, g)), signer)
    N = record!(BRAID_CHAIN, access)

    commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)
    ack = ack_leaf(BRAID_CHAIN, N)
    
    return access, ack
end

function enlist(ticketid)

    timestamp = Dates.now()
    ticket_auth_code = auth(ticketid, timestamp, RECRUIT_HMAC)

    # ---- evesdropers listening --------
    
    metadata, salt, salt_auth_code = enlist!(RECRUITER, ticketid, timestamp, ticket_auth_code) # ouptut is sent to main server    

    # ---- evesdropers listening --------
    
    #@test isbinding(ticketid, salt, salt_auth_code, RECRUIT_HMAC)  # done on the server
    @test isbinding(metadata, ticketid, salt, salt_auth_code, RECRUIT_HMAC)  # done on the server
    return token(ticketid, salt, RECRUIT_HMAC)    
end


ticketid_alice = TicketID("Alice")
token_alice = enlist(ticketid_alice)

ticketid_bob = TicketID("Bob")
token_bob = enlist(ticketid_bob)

ticketid_eve = TicketID("Eve")
token_eve = enlist(ticketid_eve)

#alice = generate(Signer, crypto)
alice = Signer(crypto, 2)
access, ack = enroll(alice, ticketid_alice, token_alice)

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
access, ack = enroll(bob, ticketid_bob, token_bob)

#eve = generate(Signer, crypto)
eve = Signer(crypto, 4)
access, ack = enroll(eve, ticketid_eve, token_eve)

### Now I have a three members

@test access in roll(BRAID_CHAIN) # coresponds to enroll!
@test id(access) in constituents(BRAID_CHAIN)
@test pseudonym(access) in members(BRAID_CHAIN)


# Here now can a braiding happen

input_generator = generator(BRAID_CHAIN)
input_members = members(BRAID_CHAIN)

braidwork = braid(input_generator, input_members, demespec, demespec, BRAIDER) 

@test Model.input_generator(braidwork) == generator(BRAID_CHAIN) 
@test Model.input_members(braidwork) == members(BRAID_CHAIN)

@test verify(braidwork, crypto)

record!(BRAID_CHAIN, braidwork)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

@test Model.output_generator(braidwork) == generator(BRAID_CHAIN)
@test Model.output_members(braidwork) == members(BRAID_CHAIN)

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
