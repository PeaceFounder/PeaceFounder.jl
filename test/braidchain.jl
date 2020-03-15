using PeaceVote: Notary, Cypher, DemeSpec, Deme, Signer, ID, Certificate, datadir, save, proposals, Option
using PeaceCypher

using PeaceFounder.Braiders
using PeaceFounder.BraidChains
import PeaceFounder
using PeaceFounder.Types: Port, BraiderConfig, RecorderConfig

for dir in [homedir() * "/.peacevote/"]
    isdir(dir) && rm(dir,recursive=true)
end

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer
uuid = demespec.uuid
deme = Deme(demespec)

maintainer = Signer(uuid,"maintainer")

# Somewhere far far away
mixer = Signer(deme,"mixer")
mixerserver = Mixer(Port(2001),deme,mixer)

server = Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

braiderconfig = BraiderConfig(Port(2000),Port(2001),3,SERVER_ID,(uuid,MIXER_ID))
recorderconfig = RecorderConfig([(uuid,maintainer.id),],server.id,Port(2002),Port(2003),Port(2004))

braider = Braider(braiderconfig,deme,server)
recorder = Recorder(recorderconfig,deme,braider,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    identification = ID("$i","today",member.id)
    cert = Certificate(identification,maintainer)
    @show register(recorderconfig,cert)
end

@sync for i in 1:3
    @async begin
        account = "account$i"
        member = Signer(deme,account * "/member")
        voter = Signer(deme,account * "/voters/$(member.id)")
        braid!(braiderconfig,deme,voter,member)
    end
end

pmember = Signer(deme,"account2" * "/member")
propose(recorderconfig,"Found peace for a change?",["yes","no","maybe"],pmember);

sleep(1)

messages = BraidChain(deme).records
proposal = proposals(messages)[1]

for i in 1:3
    account = "account$i"

    member = Signer(deme,account * "/member")
    voter = Signer(deme,account * "/voters/$(member.id)")

    option = Option(proposal,rand(1:3))
    vote(recorderconfig,option,voter)
end

