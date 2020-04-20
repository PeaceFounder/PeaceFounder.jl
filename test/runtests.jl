using DemeNet: DemeSpec, Deme, Signer, Certificate, Profile, serialize, deserialize
using PeaceVote: KeyChain, record, braid!, sync!, Vote, Proposal, BraidChain, load, proposals, attest, voters
using Recruiters: register
using PeaceFounder: PeaceFounderServer, PeaceFounderConfig, addtooken, ticket


### CleanUp ###

for dir in [homedir() * "/.demenet/"]
    isdir(dir) && rm(dir,recursive=true)
end

### Setting up the system ###

module Setup
include("setup.jl") # defines deme and systemconfig
end

uuid = Setup.uuid
demespec = DemeSpec(uuid)
deme = Deme(demespec)

server = Signer(deme,"server")

braidchain = BraidChain(deme)
pfconfig = deserialize(braidchain,PeaceFounderConfig)
system = PeaceFounderServer(pfconfig,braidchain,server)

### Testing microservices ###

maintainer = Signer(deme,"maintainer")

for i in 1:2
    account = "account$i"
    keychain = KeyChain(deme,account)
    cert = Certificate(keychain.member.id,maintainer)
    @show record(braidchain,cert)
end

# Registration with recruiters

tooken = 123244
addtooken(pfconfig,deme,tooken,maintainer)
invite = ticket(pfconfig,deme,tooken) 

profile = Profile(Dict("uuid"=>11223344))
register(invite,profile,account="account3")

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

@show tally = count(index,braidchain)

# Let's test synchronization

demesync = Deme(demespec)
bcsync = BraidChain(demesync)
sync!(bcsync,pfconfig)
@show tally = count(index,bcsync)
