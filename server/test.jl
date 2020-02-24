### A test for the server. Verifies if all services are accessable.

using DemeAssemblies: addtooken, SystemConfig

using PeaceVote
setnamespace(@__MODULE__)

import DemeAssemblies
uuid = PeaceVote.uuid("DemeAssemblies")

maintainer = PeaceVote.Signer(uuid,"maintainer")


#SERVER_PORT = 
SERVER_ID = 21908404092254970037667366726608484539958839406300700723035320376059498464496

config = SystemConfig(SERVER_ID)

#ca = PeaceVote.Signer(uuid,"ca")

### Getting certificates by proving identity
# certificates = []
# for i in 1:3
#     account = "account$i"
#     member = PeaceVote.KeyChain(uuid,account)
#     identification = PeaceVote.ID("$i","today",member.member.id)
#     cert = PeaceVote.Certificate(identification,ca)
#     push!(certificates,cert)
# end


# tookenrecords = []

# for 

# tookens = Channel(Inf)

tooken = 223434

addtooken(config.bcconfig,tooken,maintainer)


# # Each member then participates. 
# @sync for (cert,i) in zip(certificates,1:3)
#     @async begin
#         account = "account$i"
#         keychain = PeaceVote.KeyChain(uuid,account)
#         PeaceVote.register(uuid,cert)
#     end
# end

# sleep(1)

# @sync for i in 1:3
#     @async begin
#         account = "account$i"
#         keychain = PeaceVote.KeyChain(uuid,account)
#         PeaceVote.braid!(keychain)
#     end
# end

# pmember = PeaceVote.KeyChain(uuid,"account2")
# PeaceVote.propose("Found peace for a change?",["yes","no","maybe"],pmember);

# sleep(1)

# ledger = PeaceVote.Ledger(uuid)
# PeaceVote.sync!(ledger, uuid)
# braidchain = PeaceVote.braidchain(ledger,uuid)

# proposal = PeaceVote.proposals(braidchain)[1]

# @sync for i in 1:3
#     @async begin
#         account = "account$i"
#         keychain = PeaceVote.KeyChain(uuid,account)
#         option = PeaceVote.Option(proposal,rand(1:3))
#         PeaceVote.vote(option,keychain,braidchain)
#     end
# end

# sleep(1)

# # Need to add synchronization here

# ledger = PeaceVote.Ledger(uuid)
# PeaceVote.sync!(ledger, uuid)
# braidchain = PeaceVote.braidchain(ledger,uuid)

# members = PeaceVote.members(braidchain)

# for proposal in PeaceVote.proposals(braidchain)
#     tally = PeaceVote.count(uuid,proposal,braidchain)
#     @show proposal,tally
# end
