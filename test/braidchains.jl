using PeaceVote: Notary, Cypher, DemeSpec, Deme, Signer, ID, Certificate, datadir, save
using PeaceCypher

using PeaceFounder.Braiders
using PeaceFounder.BraidChains
import Synchronizers # temporary dependancy

for dir in [homedir() * "/.peacevote/"]
    isdir(dir) && rm(dir,recursive=true)
end

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer
uuid = demespec.uuid

maintainer = Signer(uuid,"maintainer")

# For the deme I also need a ledger. For now I could use Synchronizers and then think what could I do to improve.

notary = Notary(demespec)
cypher = Cypher(demespec)
ledger = Synchronizers.Ledger(datadir(uuid))
deme = Deme(demespec,notary,cypher,ledger)

# Somewhere far far away
mixer = Signer(deme,"mixer")
mixerserver = Mixer(2001,deme,mixer)

server = Signer(deme,"server")

MIXER_ID = mixer.id
SERVER_ID = server.id

braiderconfig = BraiderConfig(2000,2001,3,SERVER_ID,(uuid,MIXER_ID))
recorderconfig = BraidChainConfig(maintainer.id,[(uuid,maintainer.id),],server.id,2002,2003,2004)

braider = Braider(braiderconfig,deme,server)
recorder = BraidChainServer(recorderconfig,deme,braider,server)

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



