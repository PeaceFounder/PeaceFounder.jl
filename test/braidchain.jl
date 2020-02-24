using Community
using PeaceVote
import PeaceFounder

setnamespace(@__MODULE__)
uuid = PeaceVote.uuid("Community")

# Cleanup from the previous tests
dirs = [PeaceVote.keydir(uuid), PeaceVote.datadir(uuid), PeaceVote.communitydir(uuid)]
for dir in dirs
    isdir(dir) && rm(dir,recursive=true)
end

maintainer = PeaceVote.Signer(uuid,"maintainer")
server = PeaceVote.Signer(uuid,"server")

### Setting up configuration of the system

ballotconfig = Community.BallotConfig(2000,2001,3,server.id,(uuid,server.id))
braidchainconfig = PeaceFounder.BraidChainConfig([(uuid,maintainer.id),],maintainer.id,2002,2003,2004,ballotconfig)
systemconfig = Community.SystemConfig(2001,2005,braidchainconfig)

Community.save(systemconfig)

### Starting the server

task = @async serve(server)

sleep(2) # for waiting until server is ready

### Theese are our members

for i in 1:9
    account = "account$i"
    member = PeaceVote.Member(uuid,account)
    identification = PeaceVote.ID("$i","today",member.id)
    cert = PeaceVote.Certificate(identification,maintainer)

    @show register(cert)
end

# First braiding

@sync for i in 1:9
    account = "account$i"
    keychain = PeaceVote.KeyChain(uuid,account)
    @async PeaceVote.braid!(keychain)
end


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
