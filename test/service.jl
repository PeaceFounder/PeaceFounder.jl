import PeaceFounder: Client, Service, Mapper, Model
import .Service: ROUTER

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


alice_id = Model.id(Client.Voter(DEME))

admission = Client.seek_admission(ROUTER, alice_id, alice_ticketid, alice_token, Model.hasher(crypto))


# deme = Client.get_deme(ROUTER) # If router have already retrieved that, no need to repepeat

# alice = Client.Voter(deme)
# @test Client.get_ticket_status(ROUTER, alice_ticketid) == false
# Client.enroll!(alice, ROUTER, alice_ticketid, alice_token) # if unsuccesfull, throws an error
# @test Client.get_ticket_status(ROUTER, alice_ticketid) == true

# bob = Client.Voter(deme)
# Client.enroll!(bob, ROUTER, bob_ticketid, bob_token) 

# eve = Client.Voter(deme)
# Client.enroll!(eve, ROUTER, eve_ticketid, eve_token) 


# proposal_draft = Model.Proposal(
#     uuid = Base.UUID(23445325),
#     summary = "Are you ready for democracy?",
#     description = "",
#     ballot = Model.Ballot(["yes", "no"]),
#     open = Dates.now(),
#     closed = Dates.now() + Dates.Second(1),
# )

# Client.submit_proposal(ROUTER, proposal_draft, GUARDIAN)

# proposal = Client.list_proposals(ROUTER)[1]

# Client.cast_vote!(alice, ROUTER, proposal, Selection(2))
# Client.cast_vote!(bob, ROUTER, proposal, Selection(1))
# Client.cast_vote!(eve, ROUTER, proposal, Selection(2))


# Client.check_vote!(alice, ROUTER, proposal) # asks for consistency proof that previous commitment still holds. 


# chain_commit = Client.get_chain_commit(ROUTER)
# @test istallied(chain_commit) == false
# sleep(1)
# chain_commit = Client.get_chain_commit(ROUTER)
# @test istallied(chain_commit) == true
