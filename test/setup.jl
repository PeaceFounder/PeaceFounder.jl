### I could use this file to set up the system for the test.

using DemeNet: DemeSpec, Deme, Signer, save, DemeID
using PeaceCypher
using PeaceFounder: BraiderConfig, RecorderConfig, CertifierConfig, BraidChainConfig, PeaceFounderConfig, AddressRecord, Port, certify, serialize, deserialize
using PeaceFounder.BraidChains: BraidChain


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

braiderconfig = BraiderConfig(BRAIDER_PORT,MIXER_PORT,UInt8(3),UInt8(64),SERVER_ID,DemeID(uuid,MIXER_ID))
recorderconfig = RecorderConfig([MAINTAINER_ID,SERVER_ID],server.id,REGISTRATOR_PORT,VOTING_PORT,PROPOSAL_PORT)
braidchainconfig = BraidChainConfig(SERVER_ID,MIXER_PORT,SYNC_PORT,braiderconfig,recorderconfig)
certifierconfig = CertifierConfig(MAINTAINER_ID,SERVER_ID,TOOKEN_PORT,CERTIFIER_PORT)

peacefounderconfig = PeaceFounderConfig(braidchainconfig,certifierconfig,AddressRecord[])

braidchain = BraidChain(deme)
serialize(braidchain,peacefounderconfig)
certify(braidchain,maintainer)
deserialize(braidchain,PeaceFounderConfig)
