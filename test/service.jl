using Test
import Dates: Dates, UTC

import PeaceFounder.Server: Service, Mapper, Controllers
import PeaceFounder: Client, Schedulers
import PeaceFounder.Core.Model: Model, CryptoSpec, DemeSpec, Signer, id, approve
import PeaceFounder.Core.ProtocolSchema
import PeaceFounder.Core.Store: BraidChainLedger

crypto = CryptoSpec("sha256", "EC: P_192")
#crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

GUARDIAN = Model.generate(Signer, crypto)

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
DEMESPEC = Mapper.BRAID_CHAIN.spec

# I may need to implement a custom request method to support middleware in the Context
# or build a handler instance here. For now though I can use middleware explicitly in the code
SERVER = Client.route(Service.ROUTER) 

alice_ticketid = Model.TicketID("Alice")
alice_invite = Mapper.enlist_ticket(alice_ticketid) 
bob_invite = Mapper.enlist_ticket(Model.TicketID("Bob")) 
eve_invite = Mapper.enlist_ticket(Model.TicketID("Eve")) 

# ------------- invite gets sent over a QR code --------------

# 
@test !ProtocolSchema.isadmitted(Client.get_ticket_status(SERVER, alice_ticketid))
alice = Client.enroll!(alice_invite; server = SERVER, key = 2)
@test ProtocolSchema.isadmitted(Client.get_ticket_status(SERVER, alice_ticketid))

bob = Client.enroll!(bob_invite; server = SERVER, key = 3) 

# Braiding in between registration. Within this time admission can be attained, wheras 
# no new Membership certificates can be added to the BraidChainController. 

input_generator = Mapper.get_generator()
input_members = Mapper.get_members()

braidwork = Model.braid(input_generator, input_members, DEMESPEC.crypto, DEMESPEC, Mapper.BRAIDER) 
Mapper.submit_chain_record!(braidwork)

### 

eve = Client.enroll!(eve_invite; server = SERVER, key = 4) # Works as expected!

# Braiding

input_generator = Mapper.get_generator()
input_members = Mapper.get_members()

braidwork = Model.braid(input_generator, input_members, DEMESPEC.crypto, DEMESPEC, Mapper.BRAIDER) 
Mapper.submit_chain_record!(braidwork)

###

proposal = Model.Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Model.Ballot(["yes", "no"]),
    open = Dates.now(UTC) + Dates.Second(10),
    closed = Dates.now(UTC) + Dates.Second(60),
) |> Client.configure(SERVER) |> approve(PROPOSER)


ack = Client.enlist_proposal(SERVER, proposal)

@test Model.isbinding(proposal, ack, DEMESPEC)
@test Model.verify(ack, crypto)

Client.update_proposal_cache!(alice)
Client.update_proposal_cache!(bob)
Client.update_proposal_cache!(eve)

notify(Mapper.ENTROPY_SCHEDULER, ctime = proposal.open, wait_loop = true)

Mapper.with_ctime(proposal.open) do

    Client.cast_vote!(alice, proposal.uuid, Model.Selection(2))
    Client.cast_vote!(bob, proposal.uuid, Model.Selection(1))
    Client.cast_vote!(eve, proposal.uuid, Model.Selection(2))

end


Client.check_vote!(alice, proposal.uuid) 

Client.get_ballotbox_commit!(alice, proposal.uuid)
@test !Client.istallied(alice, proposal.uuid)

notify(Mapper.TALLY_SCHEDULER, ctime = proposal.closed, wait_loop = true)

Client.get_ballotbox_commit!(alice, proposal.uuid)
@test Client.istallied(alice, proposal.uuid)

Client.check_vote!(eve, proposal.uuid) 

@test typeof(Client.get_ballotbox_spine(SERVER, proposal.uuid)) == Vector{Model.Digest}

# Checking proposal status through endpoint
(; guard) = Client.get_proposal_instance(eve, proposal.uuid)
cast_record = Client.track_vote(SERVER, proposal.uuid, Client.tracking_code(guard, DEMESPEC))
@test cast_record.selection.option == 2
@test cast_record.seq == 1
@test cast_record.status == "valid"

# ------------- collector maliciously drops Alice's vote --------------

ballotbox = Mapper.get_ballotbox(proposal.uuid)
deleteat!(ballotbox.ledger.records, 1) # deleting alice's vote
Controllers.reset_tree!(ballotbox) 
Controllers.commit!(Mapper.POLLING_STATION, proposal.uuid, Mapper.COLLECTOR)

@test_throws ErrorException Client.check_vote!(bob, proposal.uuid) # bob finds out about misconduct

blame = Client.blame(bob, proposal.uuid) # can be published anonymously without privacy concerns 
@test Client.isbinding(blame, proposal, Model.hasher(crypto))
@test Client.verify(blame, crypto)

# Testing the API for retrieving braidchain records over the network

commit = Client.get_chain_commit(SERVER)
chain = BraidChainLedger()

for i in 1:commit.state.index
    record = Client.get_chain_record(SERVER, i)
    push!(chain, record)
end

@test Controllers.ledger(Mapper.BRAID_CHAIN) == chain
