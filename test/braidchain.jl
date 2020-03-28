using PeaceVote: Notary, Cypher, DemeSpec, Deme, Signer, Certificate, datadir, save, proposals, DemeID, ID
using PeaceCypher

using PeaceFounder.Braiders
using PeaceFounder.BraidChains
import PeaceFounder
using PeaceFounder.Types: Port, BraiderConfig, RecorderConfig, PFID, Proposal, Vote

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

braiderconfig = BraiderConfig(Port(2000),Port(2001),UInt8(3),UInt8(64),SERVER_ID,DemeID(uuid,MIXER_ID))
recorderconfig = RecorderConfig([maintainer.id,],server.id,Port(2002),Port(2003),Port(2004))

braider = Braider(braiderconfig,deme,server)
recorder = Recorder(recorderconfig,deme,braider,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    identification = PFID("$i","today",member.id)
    cert = Certificate(identification,maintainer)
    @show register(recorderconfig,cert)
end

pmember = Signer(deme,"account2" * "/member")
proposal = Proposal("Found peace for a change?",["yes","no","maybe"])
propose(recorderconfig,proposal,pmember);

@sync for i in 1:3
    @async begin
        account = "account$i"
        member = Signer(deme,account * "/member")
        voter = Signer(deme,account * "/voters/$(string(member.id))")
        braid!(braiderconfig,deme,voter,member)
    end
end


### Now I can work on reading in parsing the ledger to a BraidChain

sleep(1)

messages = BraidChain(deme).records
index = proposals(messages)[1]
proposal = messages[index]

for i in 1:3
    account = "account$i"

    member = Signer(deme,account * "/member")
    voter = Signer(deme,account * "/voters/$(string(member.id))")

    option = Vote(index,rand(1:length(proposal.document.options)))
    vote(recorderconfig,option,voter)
end

