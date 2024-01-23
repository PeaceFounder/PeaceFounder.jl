# Audit

**Note: The demonstrated audit API is in progress and is discussed further in a feature proposal [Evidence Auditing with Terminal API](https://github.com/PeaceFounder/PeaceFounder.jl/issues/19). Currently, the best auditing strategy is to recreate the braid chain and ballot box ledger from one record at a time.**

After elections have ended, the collector publishes a tally. After elections, every voter receives a final tally together with consistency proof, which proves that their vote is included in the ledger that has produced the tally. From the voter client, the voter reads four important parameters for the ballotbox:

- `deme_uuid`: a UUID of the deme where the proposal is registered;
- `proposal_index`: an index at which the proposal is recorded in the braidchain ledger;
- `ledger_length`: a number of collected votes in the ledger;
- `ledger_root`: a ballotbox ledger root checksum.

The auditor also knows a `hasher` deme used to make checksums, which is immutable when the deme is created.

To assert the integrity of the vote, an audit takes place. Let's consider abstract functions to retrieve ballotbox and braidchain ledger archives from the internet with `get_ballotbox_archive` and `get_braidchain_archive; then the auditing can be done with the following script:

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

Note that `spec` is read from the `DemeSpec` record in the braidchain, which can be trusted as the tree braidchain ledger checksum is listed within a proposal's anchor. The proposal is the first record in the history tree for the ballotbox; thus, it is bound to the `ledger_root` checksum, so the demespec record is also tied to `ledger_root`.

For convenience, an `audit` method is provided that audits both archives at the same time:

```julia
braidchain_archive = get_ballotbox_archive(uuid)
ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

@test checksum(ballotbox_archive, hasher) == ledger_root
@test audit(braidchain_archive, ballotbox_archive, hasher)

@show tally(ballotbox_archive)
```

Note that this audit does not check the honesty of the `registrar` and that it has not admitted fake users to gain more influence in the election result. Properties being verified by the audit:

- Legitimacy: only eligible voters cast their votes;
- Equality: every eligible voter can vote at most once;
- Immutability: no vote can be deleted or modified after being recorded in the ledger; 
- Tallied as Cast: all cast votes are counted honestly according to predetermined procedure; 

All these properties together ensure software independence so that the resulting tally does not depend on trust in the honest execution of either peacefounder service or braiders. In other words, the previously listed properties would not be altered if the adversary had full control over the peacefounder service and the braiders. 

The immutability is ensured by voter's clients updating their consistency proof chain, which includes their vote. If the vote gets removed from a chain, every voter who cast their vote will get proof for an inconsistent ledger state called blame. The voter can make the blame public without revealing their vote, thus ensuring immutability and persistence after votes are published. The auditable part here is the votes signed with a pseudonym, which contract voters' clients to follow up at later periods with consistency proofs. On top of that, other monitors can synchronise the ballotbox ledger and add assurances that way.
