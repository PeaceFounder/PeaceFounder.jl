using PeaceFounder.Certifiers
using PeaceCypher
using PeaceFounder.Types: CertifierConfig, Port, PFID
using PeaceVote: Signer, DemeSpec, Deme

demespec = DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
deme = Deme(demespec)

maintainer = Signer(deme,"maintainer")
server = Signer(deme,"server")

MAINTAINER_ID = maintainer.id
SERVER_ID = server.id
TOOKEN_PORT = Port(2006)
CERTIFIER_PORT = Port(2007)

config = CertifierConfig(MAINTAINER_ID,SERVER_ID,TOOKEN_PORT,CERTIFIER_PORT)

certifier = Certifier(config,deme,server)

sleep(1)

tooken = 123333

addtooken(config,deme,tooken,maintainer)

# Now the maintainer shares the tooken, demespec and ledger port with new member

member = Signer(deme,"memeber")
id = PFID("Person X","Date X",member.id)

@show cert = certify(config,deme,id,tooken)
