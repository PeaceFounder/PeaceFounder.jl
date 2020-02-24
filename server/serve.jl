import DemeAssemblies
using DemeAssemblies: SystemConfig, datadir, serve


using PeaceVote
setnamespace(@__MODULE__)
uuid = PeaceVote.uuid("DemeAssemblies")
server = PeaceVote.Signer(uuid,"server") ### One needs to take care of accounts

MAINTAINER_ID = PeaceVote.Signer(uuid,"maintainer").id

deme = MAINTAINER_ID
config = SystemConfig(deme)
system = System(config,deme,server)
