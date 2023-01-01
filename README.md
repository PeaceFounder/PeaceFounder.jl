# PeaceFounder.jl

- Peacefounder evoting system is designed around the shuffling of voters rather than votes and is a foundation that enables full public auditability and running all types of ballots one can imagine.
- Preferential voting, voting with a budget constraint, splitting long ballots in shards and using statistics to infer results, or organically changing representatives by changing a vote during a midterm is in the scope of the project.
- The current focus is a REST API that organisations could easily integrate to become more transparent and trustworthy for internally run ballots.

## Easally adaptable for your needs

A niche I am targeting is already existing homepages of different kinds of organisations that perhaps now use some internal remote voting solution that could be prone to mistrust due to manipulation and want to become more transparent and trustworthy. 

- A member willing to participate in voting would simply capture a QR code from the organisation homepage generated with the help of REST API containing a member identification code at the organisation and a token, which would automatically register it for voting.
- Peacfounder's goal is to stay out of politics. That way, each organisation can decide upon the procedures by which a proposal is given for everyone to be voted upon themselves. Because peacfounder votes are encoded into plaintext, many ballot types are possible. 
- When a proposal is finalised, voter signs it with relative generator encoded into the proposal and sends it to ballotbox for inclusion. 
- Every member receives all registered proposals to the peacefounder through REST API, all in order with strong integrity guarantees. Similarly to assert vote inclusion in finaly tally each voter receives inclusion proof which can be asserted publically in case of misconduct. 
- Upon selecting a proposal, the voter fills in a ballot on the mobile phone and, when finished, signs it with a relative generator assigned to the proposal, which protects the anonymity of the voter. The vote then is delivered anonymously to the vote collector with services like TOR. A recent port, Arti, will be of great use for making a client application. When a vote is recorded, an inclusion proof is returned to the voter, preventing any attempts to drop the votes as the evidence of doing so can be readily published and recognised by everyone to be true.

## REST API

This is a rest API for the PeaceFounder. 

```
GET /manifest # returns a current manifest file
GET /manifest/{hash}

POST /tickets : TicketID -> token::BigInt # resets token when repeated
DELETE /tickets/{TicketID}
PUT /tickets/{TicketID} : Tuple{Pseudonym, token::BigInt} -> Admission
GET /tickets/{TicketID}/status # whether token is active
GET /tickets/{TicketID}/admission : Admission

POST /braidchain/members : Member -> AckInclusion
GET /braidchain/members : Vector{Tuple{Int, Member}}
GET /braidchain/members?id={Pseudonym} : Tuple{Int, Member}
GET /braidchain/members?pseudonym={Pseudonym} : Tuple{Int, Member}

POST /braidchain/proposals : Proposal -> AckInclusion
GET /braidcahin/proposals/{UUID} : Tuple{Int, Proposal}
GET /braidchain/proposals : Vector{Tuple{Int, Proposal}}

GET /braidchain/{Int}/record : Transaction
GET /braidchain/{Int}/leaf : AckInclusion
GET /braidchain/{Int}/root : AckConsistency
GET /braidchain/commit : Commit
GET /braidchain/tar : BraidChainArchive

POST /pollingstation/{UUID}/votes : Vote -> AckInclusion
GET /pollingstation/{UUID}/spine : Vector{Digest}
GET /pollingstation/{UUID}/commit : Commit{BallotBoxState}
GET /pollingstation/{UUID}/proposal : Tuple{Int, Proposal}
GET /pollingstation/{UUID}/votes/{Int}/record : Vote
GET /pollingstation/{UUID}/votes/{Int}/leaf : AckInclusion
GET /pollingstation/{UUID}/votes/{Int}/root : AckConsistency
GET /pollingstation/{UUID}/tar : BallotBoxArchive
GET /pollingstation/collectors # necessary to make a proposal
```

## Braider

```
GET /braider : BraiderStatus
GET /braider/jobs : Vector{JobID}
GET /braider/jobs/{JobID} : JobStatus
GET /braider/jobs/{JobID}/braid : Braid
POST /braider/jobs : BraidJobSpec -> JobID
PUT /braider/jobs/{JobID} : Tuple{Vector{Pseudonym}, Generator} -> JobStatus
```

## Admin

Note that at this level I also need to implement authetification. 

```
POST /admin/ticket : Tuple{Pseudonym, Crypto, token::BigInt} # sets up the guardian
GET /admin/ticket : Pseudonym

GET /admin/braider : BraiderStatus
PUT /admin/braider : BraiderCommand -> BraiderStatus
# restarting process in case of errors
# setting allowed cryptographic groups
# making an allowlist or blocklist
# setting braider key

GET /admin/broker : BraidBrokerStatus
PUT /admin/broker : BraidBrokerCommand -> BraidBraiderStatus
# adding a braider location
# starting brading manually
# scheduling braiding
# restarting process in case of errors

GET /admin/dealer : DealerStatus # contains scheduled jobs
PUT /admin/dealer : DealerCommand -> DealerStatus
# adding beacon location
# sending a pulse manually
# passing lot without pulse

GET /admin/recruiter : RecruiterStatus
PUT /admin/recruiter : RecruiterCommand -> RecruiterStatus
# setting a recruiter key
# sets up a secret key a third party can use to push new forms and retrieve tokens

GET /admin/pollingstation : PollingStationStatus # contains a list of collectors
PUT /admin/pollingstation : PollingStaionCommand -> PollingStationStatus
# generates a collector key
# tally a given proposal manually
# adding an allowlist for monitors (who gets to backup votes)
# adding an allowlist for third party collectors who get to submit votes in case of DDOS attack
```

