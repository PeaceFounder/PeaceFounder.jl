using DemeNet: DemeSpec, Deme, Signer, Certificate, Profile, serialize, deserialize
using PeaceVote.BraidChains: members, proposals, attest, voters
using PeaceVote: KeyChain

using PeaceFounder: PeaceFounderServer, PeaceFounderConfig, addtooken, ticket
using PeaceVote.BraidChains: Vote, Proposal, BraidChain, load
using PeaceFounder

using PeaceVote.BraidChains: record, braid!, sync!

using Recruiters: register

### Perhaps I could just run julia in a process
for dir in [homedir() * "/.demenet/"]
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
### Perhaps I need to add a config 
### But it config is read from BraidChain itself
braidchain = BraidChain(deme)
pfconfig = deserialize(braidchain,PeaceFounderConfig)
system = PeaceFounderServer(pfconfig,braidchain,server)

### Now let's test the registration
maintainer = Signer(deme,"maintainer")

for i in 1:2
    account = "account$i"
    keychain = KeyChain(deme,account)
    cert = Certificate(keychain.member.id,maintainer)
    #@show record(pfconfig,cert)
    @show record(braidchain,cert)
end

### Registration with recruiters

tooken = 123244
addtooken(pfconfig,deme,tooken,maintainer)
invite = ticket(pfconfig,deme,tooken) 

profile = Profile(Dict("uuid"=>11223344))
register(invite,profile,account="account3")

# Now let's test braiding 

@sync for i in 1:3
    @async begin
        account = "account$i"
        keychain = KeyChain(deme,account)
        #braid!(pfconfig.braidchain,braidchain,keychain)
        braid!(braidchain,keychain)
    end
end

# Proposing

keychain = KeyChain(deme,"account2")
proposal = Proposal("Found peace for a change?",["yes","no","maybe"])
cert = Certificate(proposal,keychain.member)
#record(pfconfig,cert) 
record(braidchain,cert) 

sleep(1)

loadedledger = load(braidchain)
messages = attest(loadedledger,braidchain.deme.notary)
index = proposals(messages)[1]
proposal = messages[index]

# Now we can vote

for i in 1:3
    account = "account$i"
    keychain = KeyChain(deme,account)
    
    option = Vote(index,rand(1:length(proposal.document.options)))
    cert = Certificate(option,braidchain,keychain)
    #record(pfconfig,cert)
    record(braidchain,cert)
end

# Now let's count 
sleep(1)

@show tally = count(index,braidchain)

# Let's test synchronization

demesync = Deme(demespec)
bcsync = BraidChain(demesync)
sync!(bcsync,pfconfig)
@show tally = count(index,bcsync)
