import PeaceFounder 

using DemeNet: DemeSpec, Deme, Signer, Certificate, Profile
using PeaceVote: KeyChain, record, braid!, sync!, Vote, Proposal, load, proposals, attest, voters, AbstractChain
using Recruiters: register

### CleanUp ###

for dir in [homedir() * "/.demenet/"]
    isdir(dir) && rm(dir,recursive=true)
end

### Setting up the system ###
module Setup
include("setup.jl") # defines deme and systemconfig
include("serve.jl")
end

### Maintainer generates invites ###

invites = []

module Maintainer 

import PeaceFounder

using DemeNet: Signer, Deme, DemeSpec, AbstractInitializer, init, config
using Recruiters: addtooken, ticket
import ..Setup

demespec = DemeSpec(Setup.uuid)
deme = Deme(demespec)
initializer = AbstractInitializer(deme)
pfconfig = config(initializer)

maintainer = Signer(deme,"maintainer")

import ..invites

tookens = [121233,234324,123133]

for tooken in tookens
    addtooken(pfconfig,deme,tooken,maintainer)  ### Perhaps I could just extend that with recruiters!
    invite = ticket(pfconfig,deme,tooken) 
    ### One can send it, for example, over email
    push!(invites,invite)
end

end

### Registration with recruiters

for i in 1:3
    profile = Profile(Dict("uuid"=>i))    
    invite = invites[i]
    register(invite,profile,account="account$i")
end

demespec = DemeSpec(Setup.uuid)
deme = Deme(demespec)
braidchain = AbstractChain(deme)

# Braiding 

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
cert = Certificate(proposal,keychain.member)
record(braidchain,cert) 

sleep(1)
sync!(braidchain)

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
    record(braidchain,cert)
end

# Now let's count 
sleep(1)
sync!(braidchain)

@show tally = count(index,braidchain)

