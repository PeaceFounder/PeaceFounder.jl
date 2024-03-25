using PeaceFounder.Core.Store: save, load

using Test

using Dates
using PeaceFounder.Core: Model
using PeaceFounder.Server: Controllers

import .Model: CryptoSpec, pseudonym, TicketID, id, commit, verify, generator, Membership, approve, isbinding, Proposal, vote, Ballot, Selection, uuid, tally, seed, hasher, HMAC, DemeSpec, generate, Signer, key, braid, Model, select, digest, voters, members, root

import .Controllers: Registrar, admit!, enlist!, set_demehash!, Ticket, tokenid
import .Controllers: record!, commit!, ack_leaf
import .Controllers: BraidChainController, roll, constituents, state, ledger
import .Controllers: BallotBoxController, PollingStation, add!, ack_cast, set_seed!, spine


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

POLLING_STATION = PollingStation()

function enroll(signer, invite)

    # The authorization is being put within a service layer which exposes the API

    _tokenid = tokenid(invite.token, invite.hasher)
    ticket = select(Ticket, _tokenid, REGISTRAR)

    admission = admit!(REGISTRAR, id(signer), ticket.ticketid) #, auth_code)

    _commit = commit(BRAID_CHAIN)
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

alice = Signer(crypto, 2)
access, ack = enroll(alice, invite_alice)

bob = Signer(crypto, 3)
access, ack = enroll(bob, invite_bob)

eve = Signer(crypto, 4)
access, ack = enroll(eve, invite_eve)

### Now I have a three members

input_generator = generator(BRAID_CHAIN)
input_members = members(BRAID_CHAIN)

braidwork = braid(input_generator, input_members, demespec.crypto, demespec, BRAIDER) 

record!(BRAID_CHAIN, braidwork)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)


# A proposal can be constructed as

proposal = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = now(),
    closed = now() + Second(5),
    collector = demespec.collector,
    state = state(BRAID_CHAIN)
) |> approve(PROPOSER)


N = record!(BRAID_CHAIN, proposal)
commit!(BRAID_CHAIN, BRAID_CHAIN_RECORDER)

add!(POLLING_STATION, demespec, proposal, voters(BRAID_CHAIN, proposal))

_seed = digest(rand(UInt8, 16), hasher(demespec))
set_seed!(POLLING_STATION, proposal.uuid, _seed)
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)

v = vote(proposal, _seed, Selection(2), alice)
N = record!(POLLING_STATION, uuid(proposal), v) # This should have failed
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)

v = vote(proposal, _seed, Selection(1), alice)
N = record!(POLLING_STATION, uuid(proposal), v) # This should have failed
commit!(POLLING_STATION, uuid(proposal), COLLECTOR)


# BRAIDCHAIN

STORE_DIR = joinpath(tempdir(), "braidchain")

save(ledger(BRAID_CHAIN), STORE_DIR; force=true)
loaded_ledger = load(STORE_DIR)

@test loaded_ledger == ledger(BRAID_CHAIN)

# BALLOTBOX

bbox = ledger(get(POLLING_STATION, proposal))
BBOX_DIR = joinpath(tempdir(), "ballotbox")

save(bbox, BBOX_DIR; force=true)
loaded_bbox_ledger = load(BBOX_DIR)

@test loaded_bbox_ledger.records == bbox.records
@test loaded_bbox_ledger.proposal == bbox.proposal
@test loaded_bbox_ledger.spec == bbox.spec
