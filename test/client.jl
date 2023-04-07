using Test
using PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Model: CryptoSpec, DemeSpec, Signer, id, approve, Selection
using .Service: ROUTER
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


alice = Client.DemeClient()
Client.enroll!(alice, alice_invite)

bob = Client.DemeClient()
Client.enroll!(bob, bob_invite)

eve = Client.DemeClient()
Client.enroll!(eve, eve_invite)


### A simple proposal submission

proposal = Model.Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Model.Ballot(["yes", "no"]),
    open = Dates.now() + Dates.Millisecond(100),
    closed = Dates.now() + Dates.Second(3)
) |> Client.configure(ROUTER) |> approve(PROPOSER)


ack = Client.enlist_proposal(ROUTER, proposal)

### Now simple voting can be done

Client.update_deme!(alice, demespec.uuid)
Client.update_deme!(bob, demespec.uuid)
Client.update_deme!(eve, demespec.uuid)


uuid = alice.accounts[1].deme.uuid
instances = Client.list_proposal_instances(alice, uuid)
(; index, proposal) = instances[1]

Schedulers.waituntil(proposal.open + Dates.Millisecond(1000))

Client.cast_vote!(alice, uuid, index, Selection(2))
Client.cast_vote!(bob, uuid, index, Selection(1))
Client.cast_vote!(eve, uuid, index, Selection(2))

Client.check_vote!(alice, uuid, index) # asks for consistency proof that previous commitment still holds. 

Client.get_ballotbox_commit!(alice, uuid, index)
@test Client.istallied(alice, uuid, index) == false
sleep(2)

Client.get_ballotbox_commit!(alice, uuid, index)
@test Client.istallied(alice, uuid, index) == true
