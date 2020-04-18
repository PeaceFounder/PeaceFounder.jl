using DemeNet: Notary, Cypher, DemeSpec, Deme, Signer, Certificate, datadir, save, DemeID, ID
using PeaceVote.BraidChains: members, proposals, attest, voters
using PeaceCypher

#using PeaceFounder.Braiders
using PeaceFounder.BraidChains: BraiderConfig, Braider, Mixer, braid!, RecorderConfig, Proposal, Vote, BraidChain, load, Recorder, record
#using PeaceFounder.Ledgers: load
#import PeaceFounder
#using PeaceFounder.Types: Port, BraiderConfig #PFID,

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
mixerserver = Mixer(2001,deme,mixer)

server = Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

braiderconfig = BraiderConfig(2000,2001,UInt8(3),UInt8(64),SERVER_ID,DemeID(uuid,MIXER_ID))
recorderconfig = RecorderConfig([maintainer.id,],server.id,2002,2003,2004)


braider = Braider(braiderconfig,deme,server)
braidchain = BraidChain(deme) 
recorder = Recorder(recorderconfig,braidchain,braider,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    cert = Certificate(member.id,maintainer)
    @show record(recorderconfig,cert)
end

pmember = Signer(deme,"account2" * "/member")
proposal = Proposal("Found peace for a change?",["yes","no","maybe"])
cert = Certificate(proposal,pmember)

record(recorderconfig,cert);

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

loadedledger = load(braidchain)
messages = attest(loadedledger,braidchain.deme.notary)
index = proposals(messages)[1]
proposal = messages[index]

for i in 1:3
    account = "account$i"

    member = Signer(deme,account * "/member")
    voter = Signer(deme,account * "/voters/$(string(member.id))")

    option = Vote(index,rand(1:length(proposal.document.options)))
    cert = Certificate(option,voter)

    record(recorderconfig,cert)
end

