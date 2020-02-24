using Community
using PeaceVote
using Synchronizers: Ledger

setnamespace(@__MODULE__)

import PeaceVote.voters!

ledger = Ledger(tempdir() * "/ledger/")
sync!(ledger)

messages = Community.braidchain(ledger)

members = Community.members(messages)

voters = Set()
voters!(voters,messages)

for proposal in PeaceVote.proposals(messages)
    tally = count(proposal,messages)
    @show proposal,tally
end
