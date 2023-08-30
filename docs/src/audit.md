# Audit

**Note: The demonstrated audit API is in progress. Currently the best auditing strategy is to recreate braidchain and ballotbox ledger from one record at a time.**

After ellections have ended the collector publishes a tally. Every voter after ellections receives a final tally together with a consistency proof which proves that their vote is included in the ledger which have produced the tally. From the voter client voter reads four important parameters for the ballotbox:

- `deme_uuid`: an UUID of the deme where the proposal is registered;
- `proposal_index`: a index at which the proposal is recorded in the braidchain ledger;
- `ledger_length`: a number of collected votes in the ledger;
- `ledger_root`: a ballotbox ledger root checksum.

The auditor also knows a `hasher` deme uses to make checksums which is immutable at the moment deme is created.

To assert integrity of the vote an audit takes place. Let's consider abstract functions to retrieve ballotbox and braidchain ledger archives from the internet with `get_ballotbox_archive` and `get_braidchain_archive` then the auditing can be done with a following script:

```julia
braidchain_archive = get_ballotbox_archive(uuid)
ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

@test checksum(ballotbox_archive, hasher) == ledger_root
@test isbinding(braidchain_archive, ballotbox_archive, hasher)

spec = crypto(braidchain_archive)

@test audit(ballotbox_archive, spec)
@test audit(braidchain_archive)

@show tally(ballotbox_archive)
```

Note that `spec` is read from the `DemeSpec` record in the braidchain which can be trusted as the tree braidchain ledger checksum is listed within a proposal's anchor. The proposal is the first record in history tree for the ballotbox thus it is bound to `ledger_root` checksum and so demespec record is also tied to `ledger_root`.

For convinience an `audit` method is provided which audits both archives at the same time:

```julia
braidchain_archive = get_ballotbox_archive(uuid)
ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

@test checksum(ballotbox_archive, hasher) == ledger_root
@test audit(braidchain_archive, ballotbox_archive, hasher)

@show tally(ballotbox_archive)
```

Note that this audit does not check honesty of the `registrar` that it have not admitted fake users to gain more influence in the ellection result. Properties being verified by the audit:

- Legitimacy: only eligiable voters cast their votes;
- Equality: every eligiable voter can vote at most once;
- Immutability: no vote can be deleted or modified after recorded in the ledger; 
- Tallied as Cast: all cast votes are counted honestly to predetermined procedure; 

All theese properties together ensure software independence so that the resulting tally does not depend on a trust in honest execution of either peacefounder service or braiders. In other words the previously listed properties would not be altered if adversary would have a full control over the peacefounder service and the braiders. 

The immutability is ensured from voter's clients updating their consistency proof chain which includes their vote. If the vote gets removed from a chain every single voter who had cast their vote would get a proof for inconsistent ledger state called blame. The blame can be made public by the voter without revealing it's vote and thus ensures immutability and also persitance after votes are published. The auditable part here are the votes themselves signed with pseudonym which contract voter's clients to follow up at latter periods with consistency proofs. On top of that, other monitors can synchronize the ballotbox ledger and add assurances that way.
