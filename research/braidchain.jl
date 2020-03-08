using PeaceVote
using PeaceCypher


using PeaceFounder.Braiders: BraiderConfig
using PeaceFounder.BraidChains: BraidChainConfig


#setnamespace(@__MODULE__)
#uuid = PeaceVote.uuid("Community")

# Cleanup from the previous tests
#dirs = [PeaceVote.keydir(uuid), PeaceVote.datadir(uuid), PeaceVote.communitydir(uuid)]

for dir in [homedir() * "/.peacevote/"]
    isdir(dir) && rm(dir,recursive=true)
end

demespec = PeaceVote.DemeSpec("PeaceDeme",:default,:PeaceCypher,:default,:PeaceCypher,:PeaceFounder)
save(demespec) ### Necessary to connect with Mixer

uuid = demespec.uuid
### I could actually rely on DemeSpec file for creating signers
maintainer = PeaceVote.Signer(uuid,"maintainer")

#mixer = PeaceVote.Signer(uuid,"mixer")
#mixerserver = PeaceFounder.Mixer(1999,deme,mixer)

server = PeaceVote.Signer(uuid,"server")

MIXER_ID = server.id ### Self mixing
SERVER_ID = server.id

certifierconfig = nothing
braiderconfig = PeaceFounder.BraiderConfig(2000,2001,3,SERVER_ID,(uuid,MIXER_ID))
braidchainconfig = PeaceFounder.BraidChainConfig(maintainer.id,[(uuid,maintainer.id),],server.id,2002,2003,2004)
systemconfig = PeaceFounder.SystemConfig(2001,2005,certifierconfig,braiderconfig,braidchainconfig)

PeaceFounder.save(systemconfig,maintainer)

### Starting the server

system = PeaceFounder.System(demespec,server)

sleep(2) # for waiting until server is ready

### Initializing without a ledger. I will change that shortly. 
deme = Deme(demespec,nothing)

### Theese are our members

for i in 1:9
    account = "account$i"
    keychain = PeaceVote.KeyChain(deme,account)
    identification = PeaceVote.ID("$i","today",keychain.member.id)
    cert = PeaceVote.Certificate(identification,maintainer)
    @show register(deme,cert)
end

# First braiding
sleep(1)

@sync for i in 1:9
    account = "account$i"
    keychain = PeaceVote.KeyChain(deme,account) ### The issue is perhaps 
    @async PeaceVote.braid!(keychain)
end


error("STOP") ### Now I should see members and braids. 

pmember = PeaceVote.Member(uuid,"account2")
propose("Found peace for a change?",["yes","no","maybe"],pmember);

# Second braiding

@sync for i in 1:9
    account = "account$i"
    keychain = PeaceVote.KeyChain(uuid,account)
    @async PeaceVote.braid!(keychain)
end

# Now someone sends the proposal

pmember = PeaceVote.Member(uuid,"account1")
propose("Let's vote for a real change",["yes","no"],pmember);

sleep(1)

messages = braidchain()
proposals = PeaceVote.proposals(messages)

# Voting

for i in 1:9
    account = "account$i"
    keychain = PeaceVote.KeyChain(uuid,account)

    # Notice that this is after braiding 
    ### We need to also update the registrator
    voter = PeaceVote.Voter(keychain,proposals[1],messages)
    option = PeaceVote.Option(proposals[1],rand(1:3))
    vote(option,voter)

    voter = PeaceVote.Voter(keychain,proposals[2],messages)
    option = PeaceVote.Option(proposals[2],rand(1:2))
    vote(option,voter)
end
