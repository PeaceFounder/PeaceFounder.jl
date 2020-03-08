using PeaceFounder.MaintainerTools: System
using PeaceVote
using PeaceFounder

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

server = Signer(deme,"server")

### The ledger is with deme thus serving should not be hard
system = System(deme,server)

### Now let's test the registration
maintainer = Signer(deme,"maintainer")

for i in 1:3
    account = "account$i"
    keychain = KeyChain(deme,account)
    identification = ID("$i","today",keychain.member.id)
    cert = Certificate(identification,maintainer)
    @show register(deme,cert)
end

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
propose("Found peace for a change?",["yes","no","maybe"],keychain)

sleep(1)

messages = BraidChain(deme).records
proposal = proposals(messages)[1]

# Now we can vote

for i in 1:3
    account = "account$i"
    keychain = KeyChain(deme,account)
    option = Option(proposal,rand(1:3))
    vote(option,keychain)
end

# Now let's count 
sleep(1)

@show tally = count(proposal,deme)
