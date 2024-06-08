using Test

using Dates: Dates, Date, UTC

import PeaceFounder.Core.Model: Model, CryptoSpec, pseudonym, TicketID, Membership, Termination, Admission, Proposal, Ballot, Selection, generator, state, id, vote, seed, tally, approve, istallied, DemeSpec, hasher, HMAC, isbinding, Generator, generate, Signer
import PeaceFounder.Core.ProtocolSchema: tokenid, Invite, TicketStatus
import PeaceFounder.Server.Mapper
import PeaceFounder.Core.AuditTools
import PeaceFounder.Schedulers

function reboot()

    Mapper.reset_system()
    Mapper.load_system()

end

Mapper.DATA_DIR = joinpath(tempdir(), "peacefounder")
rm(Mapper.DATA_DIR, force=true, recursive=true)


crypto = CryptoSpec("sha256", "EC: P_192")
#crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

GUARDIAN = generate(Signer, crypto)

authorized_roles = Mapper.setup(crypto.group, crypto.generator) do pbkeys

    return DemeSpec(;
             uuid = Base.UUID(rand(UInt128)),
             title = "A local democratic communituy",
             email = "guardian@peacefounder.org",
             crypto = crypto,
             recorder = pbkeys[1],
             registrar = pbkeys[2],
             braider = pbkeys[3],
             proposer = pbkeys[4],
             collector = pbkeys[5]
             ) |> approve(GUARDIAN) 

end

PROPOSER = Mapper.PROPOSER
DEMESPEC = Mapper.get_demespec() #Mapper.BRAID_CHAIN[].spec

function enroll(signer, invite::Invite)

    # Authorization is done in the service layer now!

    _tokenid = tokenid(invite.token, invite.hasher)
    ticket = Mapper.get_ticket(_tokenid) do
        error("Ticket with $_tokenid not found")
    end# This is done at the service layer
    
    admission = Mapper.seek_admission(id(signer), ticket.ticketid)
    
    commit = Mapper.get_chain_commit()
    g = generator(commit)
    access = approve(Membership(admission, g, pseudonym(signer, g)), signer)

    ack = Mapper.submit_chain_record!(access)
    
    return access, ack
end


ticketid_alice = TicketID("Alice")
invite_alice = Mapper.enlist_ticket(ticketid_alice)

ticketid_bob = TicketID("Bob")
invite_bob = Mapper.enlist_ticket(ticketid_bob)

ticketid_david = TicketID("Dilan")
invite_david = Mapper.enlist_ticket(ticketid_david)

ticketid_eve = TicketID("Eve")
invite_eve = Mapper.enlist_ticket(ticketid_eve)


alice = Signer(crypto, 2)
access_alice, ack = enroll(alice, invite_alice)

bob = Signer(crypto, 3)
access_bob, ack = enroll(bob, invite_bob)

david = Signer(crypto, 5)
david_access, david_ack = enroll(david, invite_david)

eve = Signer(crypto, 4)
access_eve, ack = enroll(eve, invite_eve)

@test Mapper.get_ticket_status(ticketid_alice) do
    error("Alices ticket not found")
end isa TicketStatus

@test Mapper.get_ticket_admission(ticketid_alice) do
    error("Alices ticket not found")
end isa Admission

### Braiding

input_generator = Mapper.get_generator()
input_members = Mapper.get_members()

braidwork = Model.braid(input_generator, input_members, DEMESPEC.crypto, DEMESPEC, Mapper.BRAIDER) 
Mapper.submit_chain_record!(braidwork)

### Terminating

N = Model.index(david_ack)
david_id = id(david_access)

termination = Termination(N, david_id) |> approve(Mapper.REGISTRAR.signer)

Mapper.submit_chain_record!(termination)

reboot()

### Braid reset

input_generator = Mapper.get_generator(reset=true)
input_members = Mapper.get_members(reset=true)

braidwork = Model.braid(input_generator, input_members, DEMESPEC.crypto, DEMESPEC, Mapper.BRAIDER; reset=true) 
Mapper.submit_chain_record!(braidwork)

### 

reboot()

commit = Mapper.get_chain_commit()

proposal = Proposal(
    uuid = Base.UUID(rand(UInt128)),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = Dates.now(UTC) + Dates.Second(10),
    closed = Dates.now(UTC) + Dates.Second(60),
    collector = id(Mapper.COLLECTOR), 
    state = state(commit)
) |> approve(PROPOSER)

ack = Mapper.submit_chain_record!(proposal) # I could integrate ack 

# A lot of stuff going behind the scenes here regarding the dealer and etc
member_list = Mapper.get_chain_roll()

record = Mapper.get_chain_record(2)
ack_leaf = Mapper.get_chain_ack_leaf(2)
ack_root = Mapper.get_chain_ack_root(2)

proposal_list = Mapper.get_chain_proposal_list()
N, proposal = proposal_list[1]

@test Model.isopen(proposal; time = proposal.open) == true # inclusive
@test Model.isopen(proposal; time = proposal.closed) == false # exclusive

# replaces sleep
# task = Task() do
#     wait(Mapper.ENTROPY_CONDITION)
# end
# yield(task)
notify(Mapper.ENTROPY_SCHEDULER, ctime = proposal.open, wait_loop = true)
# wait(task)

commit = Mapper.get_ballotbox_commit(proposal.uuid)
_seed = seed(commit)

v = vote(proposal, _seed, Selection(2), alice)

ack = Mapper.cast_vote(proposal.uuid, v; ctime = proposal.open)

v = vote(proposal, _seed, Selection(1), bob)
ack = Mapper.cast_vote(proposal.uuid, v; ctime = proposal.open)

reboot()

v = vote(proposal, _seed, Selection(1), eve)
ack = Mapper.cast_vote(proposal.uuid, v; ctime = proposal.open)

spine = Mapper.get_ballotbox_spine(proposal.uuid)

ballotbox = Mapper.get_ballotbox(proposal.uuid)
@test istallied(ballotbox) == false

# replaces waituntil
# task = Task() do
#     wait(Mapper.TALLY_CONDITION)
# end
# yield(task)
notify(Mapper.TALLY_SCHEDULER, ctime = proposal.closed, wait_loop = true) # Notified but the task is not yet started
# wait(task)


@test istallied(ballotbox) == true

# Test For AuditTools

braidchain_dir = joinpath(Mapper.DATA_DIR, "public", "braidchain")
ballotbox_dir = joinpath(Mapper.DATA_DIR, "public", "ballotboxes", string(proposal.uuid))

@test AuditTools.audit_root_braidchain(braidchain_dir) == 0 
@test AuditTools.audit_root_ballotbox(ballotbox_dir) == 0

@test AuditTools.audit_commit_braidchain(braidchain_dir) == 0
@test AuditTools.audit_commit_ballotbox(ballotbox_dir) == 0

@test AuditTools.audit_tally(ballotbox_dir) == 0
@test AuditTools.audit_state(braidchain_dir) == 0

@test AuditTools.audit_eligiability(braidchain_dir, ballotbox_dir) == 0
@test AuditTools.audit_all(joinpath(Mapper.DATA_DIR, "public"), verbose=false) == 0

@test AuditTools.get_ledger_type(braidchain_dir) == "braidchain"
@test AuditTools.get_ledger_type(ballotbox_dir) == "ballotbox"

Mapper.DATA_DIR = "" # For other tests to proceed without issues
