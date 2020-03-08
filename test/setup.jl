### I could use this file to set up the system for the test.

using PeaceVote: DemeSpec, Deme, Signer, save
using PeaceCypher
using PeaceFounder.Types: BraiderConfig, RecorderConfig, CertifierConfig, SystemConfig
using PeaceFounder.DataFormat

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer
uuid = demespec.uuid
deme = Deme(demespec)

maintainer = Signer(uuid,"maintainer")
server = Signer(deme,"server")

MIXER_ID = server.id
SERVER_ID = server.id
MAINTAINER_ID = maintainer.id

MIXER_PORT = 3001 # Self mixing
BRAIDER_PORT = 3000
REGISTRATOR_PORT = 3002
VOTING_PORT = 3003
PROPOSAL_PORT = 3004
SYNC_PORT = 3005
#TOOKEN_PORT = 3006
#CERTIFIER_PORT = 3007

braiderconfig = BraiderConfig(BRAIDER_PORT,MIXER_PORT,3,SERVER_ID,(uuid,MIXER_ID))
recorderconfig = RecorderConfig(MAINTAINER_ID,[(uuid,MAINTAINER_ID),],server.id,REGISTRATOR_PORT,VOTING_PORT,PROPOSAL_PORT)
certifierconfig = nothing
systemconfig = SystemConfig(MIXER_PORT,SYNC_PORT,certifierconfig,braiderconfig,recorderconfig)

serialize(deme,systemconfig,maintainer)

