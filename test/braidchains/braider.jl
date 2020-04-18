using DemeNet: Signer, DemeSpec, Deme, save, Consensus, DemeID
using PeaceCypher
using PeaceFounder.BraidChains: BraiderConfig, Braider, Mixer, braid!


demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer

deme = Deme(demespec)
uuid = demespec.uuid

mixer = Signer(deme,"mixer")
mixerserver = Mixer(1999,deme,mixer)

server = Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

config = BraiderConfig(1998,1999,UInt8(3),UInt8(64),SERVER_ID,DemeID(uuid,MIXER_ID))

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

contractbraid = take!(braider)
@show consentbraid = Consensus(contractbraid,deme.notary)


