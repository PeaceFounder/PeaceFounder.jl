# RemoteRouter, and serve(ROUTER, socket) seems like the most basic methods I need. 
using PeaceFounder: Client, Resource, Mapper, Model
using Resource: ROUTER

crypto = Model.Crypto("SHA-256", "MODP", UInt8[1, 2, 3, 6])
GUARDIAN = Model.gen_signer(crypto)
DEME = Model.Deme("Community", Model.id(GUARDIAN), crypto)

Mapper.setup!(DEME, GUARDIAN) # also initiates an instance for a deme


ticketid = TicketID("Alice")
invite_alice = Client.get_invite(ROUTER, ticketid; hmac = nothing) # client could actually use it's known address

ticketid = TicketID("Bob")
invite_bob = Client.get_invite(ROUTER, ticketid; hmac = nothing)

ticketid = TicketID("Eve")
invite_eve = Client.get_invite(ROUTER, ticketid; hmac = nothing)


alice = Client.UserAgent()
Client.enroll!(alice, invite_alice)

bob = Client.UserAgent()
Client.enroll!(bob, invite_bob) 

eve = Client.UserAgent()
Client.enroll!(bob, invite_eve) 

### A simple proposal submission

proposal = Model.Proposal(
    uuid = Base.UUID(23445325),
    summary = "Are you ready for democracy?",
    description = "",
    ballot = Model.Ballot(["yes", "no"]),
    open = Dates.now(),
    closed = Dates.now() + Dates.Second(1),
)

Client.submit_proposal(ROUTER, proposal, GUARDIAN)

### Now simple voting can be done

deme = Client.demes(alice)[1]
proposal = Client.proposals(alice, deme)[1]

Client.cast_vote!(alice, deme, proposal, Selection(2))
Client.cast_vote!(bob, deme, proposal, Selection(1))
Client.cast_vote!(eve, deme, proposal, Selection(2))

Client.check_bbox!(alice, deme, proposal) # asks for consistency proof that previous commitment still holds. 

@test Client.istallied(alice, deme, proposal) == false
sleep(1)
@test Client.istallied(alice, deme, proposal) == true

@show Client.tally(alice, deme, proposal)

chain_commit = Client.get_chain_commit(ROUTER)
@test istallied(chain_commit) == false
sleep(1)
chain_commit = Client.get_chain_commit(ROUTER)
@test istallied(chain_commit) == true
