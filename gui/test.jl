ENV["QT_QUICK_CONTROLS_STYLE"] = "Basic"

using PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Model: CryptoSpec, DemeSpec, Signer, id, approve, Selection
import Dates
import HTTP

import QML # Needed for @qmlfunction
include("src/GUI.jl")

import .GUI: DemeItem, ProposalItem, BallotQuestion, reset!, select
import .GUI: USER_DEMES, DEME_STATUS, DEME_PROPOSALS, PROPOSAL_METADATA, PROPOSAL_STATUS, PROPOSAL_BALLOT, GUARD_STATUS, CLIENT

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

service = HTTP.serve!(Service.ROUTER, "0.0.0.0", 80)

### So far not much can be done here


try
    SERVER = Client.route("http://0.0.0.0:80")

    RECRUIT_HMAC = Model.HMAC(Mapper.get_recruit_key(), Model.hasher(demespec))

    alice_invite = Client.enlist_ticket(SERVER, Model.TicketID("Alice"), RECRUIT_HMAC) 
    bob_invite = Client.enlist_ticket(SERVER, Model.TicketID("Bob"), RECRUIT_HMAC) 
    eve_invite = Client.enlist_ticket(SERVER, Model.TicketID("Eve"), RECRUIT_HMAC) 

    Client.reset!(GUI.CLIENT)
    Client.enroll!(GUI.CLIENT, alice_invite) # internally instantiates a RemoteRouter for the client

    bob = Client.DemeClient()
    Client.enroll!(bob, bob_invite)

    eve = Client.DemeClient()
    Client.enroll!(eve, eve_invite)

    ### A simple proposal submission

    proposal = Model.Proposal(
        uuid = Base.UUID(23445325),
        summary = "Should the city ban all personal vehicle usage?",
        description = """
Introduction:

The growing use of automotive vehicles in cities has led to an increase in traffic congestion, air pollution, and carbon emissions, negatively impacting the environment and the health of citizens. To mitigate these issues, it is essential to encourage the use of alternative forms of transportation, such as cycling, walking, public transit, and electric vehicles. In this proposal, we recommend implementing a ban on automotive vehicle usage in the city and promoting alternative modes of transportation.

Objective:

The primary objective of this proposal is to reduce the usage of automotive vehicles in the city and promote the use of alternative forms of transportation. By doing so, we aim to decrease traffic congestion, improve air quality, and reduce carbon emissions. This proposal also aims to encourage citizens to adopt a healthier lifestyle by promoting walking and cycling as alternatives to automotive transportation.

Methodology:

Ban on Automotive Vehicles: The first step in implementing this proposal is to ban the usage of automotive vehicles in the city. This ban would restrict the entry of vehicles into the city, with the exception of emergency and essential services. The ban could be implemented in phases, with initial restrictions on certain days of the week and gradually expanding to a full-time ban.
Promotion of Alternative Transportation: To encourage citizens to use alternative modes of transportation, the city government could invest in infrastructure for cycling and walking, including bike lanes and pedestrian pathways. Additionally, public transit services could be improved, and electric vehicles could be promoted as a viable alternative to traditional automobiles.
Awareness Campaign: To inform citizens about the ban on automotive vehicles and promote alternative forms of transportation, an awareness campaign could be launched. This campaign could include advertising in traditional and social media, as well as educational programs in schools and public events.

Expected Outcomes:

Reduced Traffic Congestion: The ban on automotive vehicles is expected to reduce traffic congestion in the city, as fewer vehicles would be on the road.
Improved Air Quality: The reduction in automotive vehicle usage would lead to improved air quality, as fewer carbon emissions would be released into the environment.
Healthier Lifestyle: Encouraging walking and cycling as alternative forms of transportation could lead to a healthier lifestyle for citizens.
Increased Use of Public Transit: Improving public transit services could lead to an increase in the use of public transportation by citizens.

Conclusion:

In conclusion, implementing a ban on automotive vehicle usage in the city and promoting alternative forms of transportation is a viable solution to reduce traffic congestion, improve air quality, and promote a healthier lifestyle. The success of this proposal relies on the cooperation of citizens and the government to work together to reduce the negative impact of automotive transportation on the environment and the health of citizens.

CREDITS to ChatGPT
""",
        ballot = Model.Ballot(["Yes", "No"]),
        open = Dates.now() + Dates.Millisecond(200),
        closed = Dates.now() + Dates.Second(10)
    ) |> Client.configure(SERVER) |> approve(PROPOSER)


    ack = Client.enlist_proposal(SERVER, proposal)

    ### Now simple voting can be done
    Client.update_deme!(GUI.CLIENT, demespec.uuid)
    Client.update_deme!(bob, demespec.uuid)
    
    sleep(1)

    uuid = CLIENT.accounts[1].deme.uuid
    instances = Client.list_proposal_instances(CLIENT, uuid)
    (; index, proposal) = instances[1]

    Client.cast_vote!(bob, uuid, index, Model.Selection(2))

    
    GUI.load_view() do

        GUI.setHome()

    end


finally
    close(service)
end
