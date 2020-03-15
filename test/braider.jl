using PeaceVote
using PeaceCypher
using PeaceFounder.Braiders
using PeaceFounder.Types: Port, BraiderConfig


demespec = PeaceVote.DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer

deme = Deme(demespec)
uuid = demespec.uuid

mixer = PeaceVote.Signer(deme,"mixer")
mixerserver = Mixer(1999,deme,mixer)

server = PeaceVote.Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

config = BraiderConfig(Port(1998),Port(1999),3,SERVER_ID,(uuid,MIXER_ID))

braider = Braider(config,deme,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    push!(braider.voters,member.id)
end

# ### Users do:

@sync for i in 1:3
    @async begin
        account = "account$i"
        member = Signer(deme,account * "/member")
        voter = Signer(deme,account * "/voters/$(member.id)")
        braid!(config,deme,voter,member)
    end
end

### After that gatekeeper gets ballot

@show take!(braider)
