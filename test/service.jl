using Test
import PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Service: ROUTER
import Dates

crypto = Model.Crypto("SHA-256", "MODP", UInt8[1, 2, 3, 6])
GUARDIAN = Model.gen_signer(crypto)
DEME = Model.Deme("Community", Model.id(GUARDIAN), crypto)

Mapper.setup!(DEME, GUARDIAN) # also initiates an instance for a deme
RECRUITER_AUTH_KEY = Mapper.get_recruit_key()
RECRUIT_HMAC = Model.HMAC(RECRUITER_AUTH_KEY, Model.hasher(DEME))


alice_ticketid = Model.TicketID("Alice")
alice_token = Client.enlist_ticket(ROUTER, alice_ticketid, RECRUIT_HMAC) 

bob_ticketid = Model.TicketID("Bob")
bob_token = Client.enlist_ticket(ROUTER, bob_ticketid, RECRUIT_HMAC) 

eve_ticketid = Model.TicketID("Eve")
eve_token = Client.enlist_ticket(ROUTER, eve_ticketid, RECRUIT_HMAC) 

# ------------- token and ticketid gets sent over a QR code --------------

deme = Client.get_deme(ROUTER) # If router have already retrieved that, no need to repepeat
alice = Client.Voter(deme)

@test !Model.isadmitted(Client.get_ticket_status(ROUTER, alice_ticketid))
Client.enroll!(alice, ROUTER, alice_ticketid, alice_token) # if unsuccesfull, throws an error
@test Model.isadmitted(Client.get_ticket_status(ROUTER, alice_ticketid))

bob = Client.Voter(deme)
Client.enroll!(bob, ROUTER, bob_ticketid, bob_token) 

eve = Client.Voter(deme)
Client.enroll!(eve, ROUTER, eve_ticketid, eve_token) 

proposal_draft = Model.Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Model.Ballot(["yes", "no"]),
    open = Dates.now() + Dates.Millisecond(100),
    closed = Dates.now() + Dates.Second(3)
)

proposal, ack = Client.enlist_proposal(ROUTER, proposal_draft, GUARDIAN)

@test Model.isbinding(proposal, ack, DEME)
@test Model.verify(ack, crypto)

Client.update_proposal_cache!(alice, ROUTER)
Client.update_proposal_cache!(bob, ROUTER)
Client.update_proposal_cache!(eve, ROUTER)

Schedulers.waituntil(proposal.open + Dates.Millisecond(1000))

Client.cast_vote!(alice, ROUTER, proposal.uuid, Model.Selection(2))
Client.cast_vote!(bob, ROUTER, proposal.uuid, Model.Selection(1))
Client.cast_vote!(eve, ROUTER, proposal.uuid, Model.Selection(2))

Client.check_vote!(alice, ROUTER, proposal.uuid) 

chain_commit = Client.get_ballotbox_commit(ROUTER, proposal.uuid)
@test Model.istallied(chain_commit) == false

Schedulers.waituntil(proposal.closed + Dates.Millisecond(100))

chain_commit = Client.get_ballotbox_commit(ROUTER, proposal.uuid)
@test Model.istallied(chain_commit) == true

Client.check_vote!(eve, ROUTER, proposal.uuid) 

@test typeof(Client.get_ballotbox_spine(ROUTER, proposal.uuid)) == Vector{Model.Digest}

# ------------- collector maliciously drops Alice's vote --------------

ballotbox = Mapper.ballotbox(proposal.uuid)
deleteat!(ballotbox.ledger, 1) # deleting alice's vote
Model.reset_tree!(ballotbox) 
Model.commit!(Mapper.POLLING_STATION[], proposal.uuid, Mapper.GUARDIAN[])

@test_throws ErrorException Client.check_vote!(bob, ROUTER, proposal.uuid) # bob finds out about misconduct

blame = Client.blame(bob, proposal.uuid) # can be published anonymously without privacy concerns 
@test Client.isbinding(blame, proposal, Model.hasher(crypto))
@test Client.verify(blame, crypto)
