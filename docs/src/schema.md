# REST API

This is an approximate rest API for the PeaceFounder. In future, this will be properly generated and documented from the code. 

```
GET /deme # returns a current manifest file
GET /deme/{hash}

POST /tickets : Tuple{TicketID, DateTime, auth_code::Digest} -> Tuple{salt::Vector{UInt8}, auth_code::Digest} # resets token when repeated
DELETE /tickets/{TicketID}
PUT /tickets/{TicketID} : Tuple{Pseudonym, auth_code::Digest} -> Admission
GET /tickets/{TicketID} : TicketStatus

POST /braidchain/members : Member -> AckInclusion{ChainState}
GET /braidchain/members : Vector{Tuple{Int, Member}}
GET /braidchain/members?id={Pseudonym} : Tuple{Int, Member}
GET /braidchain/members?pseudonym={Pseudonym} : Tuple{Int, Member}

POST /braidchain/proposals : Proposal -> AckInclusion
GET /braidcahin/proposals/{UUID} : Tuple{Int, Proposal}
GET /braidchain/proposals : Vector{Tuple{Int, Proposal}}

GET /braidchain/{Int}/record : Transaction
GET /braidchain/{Int}/leaf : AckInclusion{ChainState}
GET /braidchain/{Int}/root : AckConsistency{ChainState}
GET /braidchain/commit : Commit{ChainState}
GET /braidchain/tar : BraidChainArchive

POST /pollingstation/{UUID}/votes : Vote -> CastAck
GET /pollingstation/{UUID}/spine : Vector{Digest}
GET /pollingstation/{UUID}/commit : Commit{BallotBoxState}
GET /pollingstation/{UUID}/proposal : Tuple{Int, Proposal}
GET /pollingstation/{UUID}/votes/{Int}/record : CastRecord
GET /pollingstation/{UUID}/votes/{Int}/receipt : CastReceipt
GET /pollingstation/{UUID}/votes/{Int}/leaf : AckInclusion{BallotBoxState}
GET /pollingstation/{UUID}/votes/{Int}/root : AckConsistency{BallotBoxState}
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
POST /admin/ticket : Tuple{Pseudonym, CryptoSpec, token::BigInt} # sets up the guardian
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
