### I could use this file to set up the system for the test.

using PeaceVote: DemeSpec, Deme, Signer, save, DemeID
using PeaceCypher
using PeaceFounder.Types: BraiderConfig, RecorderConfig, CertifierConfig, SystemConfig, AddressRecord, Port
using PeaceFounder.DataFormat

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer
uuid = demespec.uuid
deme = Deme(demespec)

maintainer = Signer(deme,"maintainer")
server = Signer(deme,"server")

MIXER_ID = server.id
SERVER_ID = server.id
MAINTAINER_ID = maintainer.id

MIXER_PORT = Port(3001) # Self mixing
BRAIDER_PORT = Port(3000)
REGISTRATOR_PORT = Port(3002)
VOTING_PORT = Port(3003)
PROPOSAL_PORT = Port(3004)
SYNC_PORT = Port(3005)
TOOKEN_PORT = Port(3006)
CERTIFIER_PORT = Port(3007)

braiderconfig = BraiderConfig(BRAIDER_PORT,MIXER_PORT,3,SERVER_ID,DemeID(uuid,MIXER_ID))
recorderconfig = RecorderConfig([MAINTAINER_ID,SERVER_ID],server.id,REGISTRATOR_PORT,VOTING_PORT,PROPOSAL_PORT)
certifierconfig = CertifierConfig(MAINTAINER_ID,SERVER_ID,TOOKEN_PORT,CERTIFIER_PORT)
systemconfig = SystemConfig(MIXER_PORT,SYNC_PORT,SERVER_ID,certifierconfig,braiderconfig,recorderconfig,AddressRecord[])

serialize(deme,systemconfig,maintainer)
deserialize(deme,SystemConfig)
