using Test
import PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Model: CryptoSpec, DemeSpec, Signer, id, approve
import .Service: ROUTER
import Dates

crypto = CryptoSpec("SHA-256", "MODP", UInt8[1, 2, 3, 6])

GUARDIAN = Model.generate(Signer, crypto)
PROPOSER = Model.generate(Signer, crypto)


Mapper.initialize!(crypto)
roles = Mapper.system_roles()

demespec = DemeSpec(; 
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    crypto = crypto,
                    guardian = id(GUARDIAN),
                    recorder = roles.recorder,
                    recruiter = roles.recruiter,
                    braider = roles.braider,
                    proposer = id(PROPOSER),
                    collector = roles.collector
) |> approve(GUARDIAN) 

Mapper.capture!(demespec)

RECRUIT_HMAC = Model.HMAC(Mapper.get_recruit_key(), Model.hasher(demespec))

alice_invite = Client.enlist_ticket(ROUTER, Model.TicketID("Alice"), RECRUIT_HMAC) 
bob_invite = Client.enlist_ticket(ROUTER, Model.TicketID("Bob"), RECRUIT_HMAC) 
eve_invite = Client.enlist_ticket(ROUTER, Model.TicketID("Eve"), RECRUIT_HMAC) 

# ------------- invite gets sent over a QR code --------------

@test !Model.isadmitted(Client.get_ticket_status(ROUTER, alice_invite.ticketid))
alice = Client.enroll!(alice_invite)
@test Model.isadmitted(Client.get_ticket_status(ROUTER, alice_invite.ticketid))

bob = Client.enroll!(bob_invite) 
eve = Client.enroll!(eve_invite)

proposal = Model.Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Model.Ballot(["yes", "no"]),
    open = Dates.now() + Dates.Millisecond(100),
    closed = Dates.now() + Dates.Second(3)
) |> Client.configure(ROUTER) |> approve(PROPOSER)


ack = Client.enlist_proposal(ROUTER, proposal)

@test Model.isbinding(proposal, ack, demespec)
@test Model.verify(ack, crypto)

Client.update_proposal_cache!(alice)
Client.update_proposal_cache!(bob)
Client.update_proposal_cache!(eve)

Schedulers.waituntil(proposal.open + Dates.Millisecond(1500))

Client.cast_vote!(alice, proposal.uuid, Model.Selection(2))
Client.cast_vote!(bob, proposal.uuid, Model.Selection(1))
Client.cast_vote!(eve, proposal.uuid, Model.Selection(2))

Client.check_vote!(alice, proposal.uuid) 


Client.get_ballotbox_commit!(alice, proposal.uuid)
@test !Client.istallied(alice, proposal.uuid)

Schedulers.waituntil(proposal.closed + Dates.Millisecond(300))

Client.get_ballotbox_commit!(alice, proposal.uuid)
@test Client.istallied(alice, proposal.uuid)


Client.check_vote!(eve, proposal.uuid) 

@test typeof(Client.get_ballotbox_spine(ROUTER, proposal.uuid)) == Vector{Model.Digest}

# ------------- collector maliciously drops Alice's vote --------------

ballotbox = Mapper.ballotbox(proposal.uuid)
deleteat!(ballotbox.ledger, 1) # deleting alice's vote
Model.reset_tree!(ballotbox) 
Model.commit!(Mapper.POLLING_STATION[], proposal.uuid, Mapper.COLLECTOR[])

@test_throws ErrorException Client.check_vote!(bob, proposal.uuid) # bob finds out about misconduct

blame = Client.blame(bob, proposal.uuid) # can be published anonymously without privacy concerns 
@test Client.isbinding(blame, proposal, Model.hasher(crypto))
@test Client.verify(blame, crypto)
