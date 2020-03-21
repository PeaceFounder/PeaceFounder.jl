using PeaceFounder.MaintainerTools: System, addtooken
using PeaceFounder.Types: PFID, Vote, Proposal
using PeaceFounder
using PeaceVote

### Perhaps I could just run julia in a process
for dir in [homedir() * "/.peacevote/"]
    isdir(dir) && rm(dir,recursive=true)
end

module Setup
include("setup.jl") # defines deme and systemconfig
end

uuid = Setup.uuid
demespec = DemeSpec(uuid)
deme = Deme(demespec)
demesync = Deme(demespec)


server = Signer(deme,"server")

### The ledger is with deme thus serving should not be hard
system = System(deme,server)

### Now let's test the registration
maintainer = Signer(deme,"maintainer")

for i in 1:2
    account = "account$i"
    keychain = KeyChain(deme,account)
    identification = PFID("$i","today",keychain.member.id)
    cert = Certificate(identification,maintainer)
    @show register(deme,cert)
end

### Maintainer adds a tooken

tooken = 123244
addtooken(deme,tooken,maintainer)

# One can send it over email with sendinvite method from MaintainerTools.
###

keychain = KeyChain(deme,"account3")
id = PFID("3","today",keychain.member.id)
register(deme,id,tooken)

# Now let's test braiding 

@sync for i in 1:3
    @async begin
        account = "account$i"
        keychain = KeyChain(deme,account)
        braid!(keychain)
    end
end

# Proposing

keychain = KeyChain(deme,"account2")
proposal = Proposal("Found peace for a change?",["yes","no","maybe"])
propose(proposal,keychain)

sleep(1)

messages = BraidChain(deme).records
index = proposals(messages)[1]
proposal = messages[index]


# Now we can vote

for i in 1:3
    account = "account$i"
    keychain = KeyChain(deme,account)
    
    option = Vote(index,rand(1:length(proposal.document.options)))
    vote(option,keychain)
end

# Now let's count 
sleep(1)

@show tally = count(index,proposal.document,deme)

# Let's test synchronization

sync!(demesync)
@show tally = count(index,proposal.document,demesync)
