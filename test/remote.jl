using Test
using PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Model: CryptoSpec, DemeSpec, Signer, id, approve, Selection
import Dates

const PORT = 3222

crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

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

#service = HTTP.serve!(Service.ROUTER, "0.0.0.0", 80)

service = Service.serve(async=true, port=PORT)


try
    SERVER = Client.route("http://0.0.0.0:$PORT")

    RECRUIT_HMAC = Model.HMAC(Mapper.get_recruit_key(), Model.hasher(demespec))

    alice_invite = Mapper.enlist_ticket(Model.TicketID("Alice")) 
    bob_invite = Mapper.enlist_ticket(Model.TicketID("Bob")) 
    eve_invite = Mapper.enlist_ticket(Model.TicketID("Eve")) 

    alice = Client.DemeClient()
    Client.enroll!(alice, alice_invite; key = 2) # internally instantiates a RemoteRouter for the client

    bob = Client.DemeClient()
    Client.enroll!(bob, bob_invite; key = 3)

    eve = Client.DemeClient()
    Client.enroll!(eve, eve_invite; key = 4)

    ### A simple proposal submission

    proposal = Model.Proposal(
        uuid = Base.UUID(23445325),
        summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
        description = """
 A very long description
    """,
        ballot = Model.Ballot(["yes", "no"]),
        open = Dates.now() + Dates.Millisecond(200),
        closed = Dates.now() + Dates.Second(10)
    ) |> Client.configure(SERVER) |> approve(PROPOSER)


    ack = Client.enlist_proposal(SERVER, proposal)

    ### Now simple voting can be done

    Client.update_deme!(alice, demespec.uuid)
    Client.update_deme!(bob, demespec.uuid)
    Client.update_deme!(eve, demespec.uuid)


    uuid = alice.accounts[1].deme.uuid
    instances = Client.list_proposal_instances(alice, uuid)
    (; index, proposal) = instances[1]

    Schedulers.waituntil(proposal.open + Dates.Millisecond(4000))

    Client.cast_vote!(alice, uuid, index, Selection(2))
    Client.cast_vote!(bob, uuid, index, Selection(1))
    Client.cast_vote!(eve, uuid, index, Selection(2))

    Client.check_vote!(alice, uuid, index) # asks for consistency proof that previous commitment still holds. 

    Client.get_ballotbox_commit!(alice, uuid, index)
    @test Client.istallied(alice, uuid, index) == false

    Schedulers.waituntil(proposal.closed + Dates.Millisecond(200))

    Client.get_ballotbox_commit!(alice, uuid, index)
    @test Client.istallied(alice, uuid, index) == true

finally
    close(service)
end
