using DemeNet: DemeSpec, Deme, Signer, Certificate, Profile
using PeaceVote.BraidChains: members, proposals, attest, voters
using PeaceVote: KeyChain

using PeaceFounder.MaintainerTools: System, addtooken, ticket
using PeaceFounder.Types: PFID, Vote, Proposal, BraidChain
using PeaceFounder

import Recruiters


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
braidchain = BraidChain(deme)
system = System(braidchain,server)

### Now let's test the registration
maintainer = Signer(deme,"maintainer")

for i in 1:2
    account = "account$i"
    keychain = KeyChain(deme,account)
    cert = Certificate(keychain.member.id,maintainer)
    @show register(braidchain,cert)
end

### Registration with recruiters

tooken = 123244
addtooken(braidchain,tooken,maintainer)
invite = ticket(braidchain,tooken) 

profile = Profile(Dict("uuid"=>11223344))
Recruiters.register(invite,profile,account="account3")

# Now let's test braiding 

@sync for i in 1:3
    @async begin
        account = "account$i"
        keychain = KeyChain(deme,account)
        braid!(braidchain,keychain)
    end
end

# Proposing

keychain = KeyChain(deme,"account2")
proposal = Proposal("Found peace for a change?",["yes","no","maybe"])
propose(braidchain,proposal,keychain)

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
    vote(braidchain,option,keychain)
end

# Now let's count 
sleep(1)

@show tally = count(index,braidchain)

# Let's test synchronization

demesync = Deme(demespec)
bcsync = BraidChain(demesync)
sync!(bcsync)
@show tally = count(index,bcsync)
