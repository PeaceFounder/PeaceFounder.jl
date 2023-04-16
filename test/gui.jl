ENV["QT_QUICK_CONTROLS_STYLE"] = "Basic"

# A simple test for time_window
include("../gui/src/GUI.jl")
import .GUI: time_period, time_window
import Dates: Dates, Hour, Minute

@show time_period(Hour(24))
@show time_period(Hour(37))

@show time_period(Minute(70))
@show time_period(Minute(15))
@show time_period(Minute(1))

time_window(Dates.now(), Dates.now() + Dates.Day(1); time = Dates.now() + Dates.Hour(12)) |> println
time_window(Dates.now(), Dates.now() + Dates.Day(1); time = Dates.now() + Dates.Hour(25)) |> println
time_window(Dates.now(), Dates.now() + Dates.Day(1); time = Dates.now() + Dates.Hour(48)) |> println
time_window(Dates.now(), Dates.now() + Dates.Day(1); time = Dates.now() - Dates.Hour(12)) |> println

# Testing of GUI functions

using PeaceFounder: Client, Service, Mapper, Model, Schedulers
import .Model: CryptoSpec, DemeSpec, Signer, id, approve, Selection
import HTTP
import QML # Needed for @qmlfunction


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
        description = "",
        ballot = Model.Ballot(["Yes", "No"]),
        open = Dates.now() + Dates.Millisecond(200),
        closed = Dates.now() + Dates.Second(10)
    ) |> Client.configure(SERVER) |> approve(PROPOSER)


    ack = Client.enlist_proposal(SERVER, proposal)

    ### Now simple voting can be done
    Client.update_deme!(GUI.CLIENT, demespec.uuid)
    Client.update_deme!(bob, demespec.uuid)
        
    
    sleep(1)

    GUI.setDeme(demespec.uuid)

    instances = Client.list_proposal_instances(GUI.CLIENT, demespec.uuid)
    (; index, proposal) = instances[1]

    GUI.setProposal(index)

    Client.cast_vote!(GUI.CLIENT, demespec.uuid, index, Model.Selection(2))

    GUI.refreshDeme()
    GUI.refreshProposal()
    GUI.refreshHome()
        
finally 
    close(service)
end
