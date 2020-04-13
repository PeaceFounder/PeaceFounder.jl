using DemeNet: Notary, Cypher, DemeSpec, Deme, Signer, Certificate, datadir, save, DemeID, ID
using PeaceVote.BraidChains: members, proposals, attest, voters
using PeaceCypher

using PeaceFounder.Braiders
using PeaceFounder.BraidChains
using PeaceFounder.Ledgers: load
#import PeaceFounder
using PeaceFounder.Types: Port, BraiderConfig, RecorderConfig, Proposal, Vote, BraidChain #PFID,

for dir in [homedir() * "/.demenet/"]
    isdir(dir) && rm(dir,recursive=true)
end

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer
uuid = demespec.uuid
deme = Deme(demespec)

maintainer = Signer(deme,"maintainer")

# Somewhere far far away
mixer = Signer(deme,"mixer")
mixerserver = Mixer(Port(2001),deme,mixer)

server = Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

braiderconfig = BraiderConfig(Port(2000),Port(2001),UInt8(3),UInt8(64),SERVER_ID,DemeID(uuid,MIXER_ID))
recorderconfig = RecorderConfig([maintainer.id,],server.id,Port(2002),Port(2003),Port(2004))


braider = Braider(braiderconfig,deme,server)
braidchain = BraidChain(deme) 
recorder = Recorder(recorderconfig,braidchain,braider,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    #identification = PFID("$i","today",member.id)
    #cert = Certificate(identification,maintainer)
    cert = Certificate(member.id,maintainer)
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

loadedledger = load(braidchain.ledger)
messages = attest(loadedledger,braidchain.deme.notary)
index = proposals(messages)[1]
proposal = messages[index]

for i in 1:3
    account = "account$i"

    member = Signer(deme,account * "/member")
    voter = Signer(deme,account * "/voters/$(string(member.id))")

    option = Vote(index,rand(1:length(proposal.document.options)))
    vote(recorderconfig,option,voter)
end

