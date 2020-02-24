using PeaceVote
using PeaceFounder
using PeaceFounder: BraiderConfig, CertifierConfig, BraidChainConfig, SystemConfig, Port

#using Sockets: @ip_str

### First we need to make a DemeSpec file

name = "PeaceDeme"

crypto = quote
G = CryptoGroups.Scep256k1Group()
hash(x::AbstractString) = parse(BigInt,Nettle.hexdigest("sha256",x),base=16)

Signer() = CryptoSignatures.Signer(G)
Signature(x::AbstractString,signer) = CryptoSignatures.DSASignature(hash(x),signer)
verify(data,signature) = CryptoSignatures.verify(signature,G) && hash(data)==signature.hash ? hash("$(signature.pubkey)") : nothing

(Signer,Signature,verify,hash)
end

deps = Symbol[:Nettle,:CryptoGroups,:CryptoSignatures]


notary = Notary(crypto,deps)
demespec = DemeSpec(name,crypto,deps,:PeaceFounder,notary)
save(demespec)

### The next step is to configure the server

# Maintainer sends the demespec file to the server. The server generates a server key pair and returns ID. Also configures the server such that it automatically starts to serve demespec file. That makes the server to stay in the listening state which allows maintainer to upload the configuration file specifying how the machine should work.

# SSH = "pi@192.1.1.1"
# SERVER_ID = configure(SSH,demespec)

deme = Deme(demespec,nothing)
server = Signer(deme,"server")

SERVER_ID = server.id

# Now maintainer finishes the configuration

maintainer = PeaceVote.Signer(deme,"maintainer")
MAINTAINER_ID = maintainer.id


MIXER_ID = (deme.spec.uuid,SERVER_ID) # Self mixing 
CA_ID = (deme.spec.uuid,SERVER_ID)
TOOKEN_CA = MAINTAINER_ID

N = 3 # Number of participants per ballot/braid

### For local tests

MIXER_PORT = 2001 # Self mixing
BRAIDER_PORT = 2000
REGISTRATOR_PORT = 2002
VOTING_PORT = 2003
PROPOSAL_PORT = 2004
SYNC_PORT = 2005
TOOKEN_PORT = 2006
CERTIFIER_PORT = 2007


### For some remote action

# MIXER_PORT = Port(SERVER_IP,2001) # Self mixing
# BRAIDER_PORT = Port(SERVER_IP,2000)
# REGISTRATOR_PORT = Port(SERVER_IP,2002)
# VOTING_PORT = Port(SERVER_IP,2003)
# PROPOSAL_PORT = Port(SERVER_IP,2004)
# SYNC_PORT = Port(SERVER_IP,2005)

certifier = CertifierConfig(TOOKEN_CA,SERVER_ID,TOOKEN_PORT,CERTIFIER_PORT)
braider = BraiderConfig(BRAIDER_PORT,MIXER_PORT,N,SERVER_ID,MIXER_ID)
braidchain = BraidChainConfig(MAINTAINER_ID,[CA_ID,],SERVER_ID,REGISTRATOR_PORT,VOTING_PORT,PROPOSAL_PORT)

systemconfig = SystemConfig(MIXER_PORT,SYNC_PORT,certifier,braider,braidchain)

PeaceFounder.save(systemconfig,maintainer)

### After that one may upload the config file to the server.
# upload(deme,SERVER_IP)
