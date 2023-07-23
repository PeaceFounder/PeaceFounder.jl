"""
After ellections have ended the collector publishes a tally. To assert that votes have been 
accuratelly counted and that only legitimate voters have participated an audit takes place.

Every voter after ellections receives a final tally together with a consistency proof 
which proves that their vote is included in the ledger which have produced the tally. 
From the voter client voter reads four important parameters for the ballotbox:

- `deme_uuid`: an UUID of the deme where the proposal is registered;
- `proposal_index`: a index at which the proposal is recorded in the braidchain ledger;
- `ledger_length`: a number of collected votes in the ledger;
- `ledger_root`: a ballotbox ledger root checksum.

The auditor also knows a `hasher` deme uses to make checksums which is immutable at the
moment deme is created.

Let's consider abstract functions to retrieve ballotbox and braidchain ledger archives from
the internet with `get_ballotbox_archive` and `get_braidchain_archive` then the auditing
can be done with a following script:

    braidchain_archive = get_ballotbox_archive(uuid)
    ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

    @test checksum(ballotbox_archive, hasher) == ledger_root
    @test isbinding(braidchain_archive, ballotbox_archive, hasher)
    
    spec = crypto(braidchain_archive)
    
    @test audit(ballotbox_archive, spec)
    @test audit(braidchain_archive)

    @show tally(ballotbox_archive)

Note that `spec` is read from the `DemeSpec` record in the braidchain which can be trusted as 
the tree braidchain ledger checksum is listed within a proposal's anchor. The proposal is 
the first record in history tree for the ballotbox thus it is bound to `ledger_root` 
checksum and so demespec record is also tied to `ledger_root`.

For convinience an `audit` method is provided which audits both archives at the same time:

    braidchain_archive = get_ballotbox_archive(uuid)
    ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

    @test checksum(ballotbox_archive, hasher) == ledger_root
    @test audit(braidchain_archive, ballotbox_archive, hasher)
    
    @show tally(ballotbox_archive)    

Note that this audit does not check honesty of the `registrar` that it have not admitted fake
users to gain more influence in the ellection result. Properties being verified by the audit:

- Legitimacy: only and all eligiable voters cast their votes;
- Fairness: every eligiable voter can vote at most once;
- Immutability: no vote can be deleted or modified when recorded in the ledger; 
- Tallied as Cast: all cast votes are counted honestly to predetermined procedure; 
- Software independence: the previously audited properties for the evidence does not 
depend on a trust in honest execution of peacefounder service nor honesty of the braiders
who provides new pseudonyms for the deme members. In other words the previously listed 
properties would not be altered if adversary would have a full control over the peacefounder 
service and the braiders. 

The immutability is ensured from voter's clients updating their consistency proof chain which includes their vote. If the vote gets removed from a chain every single voter who had cast their vote would get a proof for inconsistent ledger state called blame. The blame can be made public by the voter without revealing it's vote and thus ensures immutability and also persitance after votes are published. The auditable part here are the votes themselves signed with pseudonym which contract voter's clients to follow up at latter periods with consistency proofs. On top of that, other monitors can synchronize the ballotbox ledger and add assurances that way.

"""
module AuditTools

using ..Model: Transaction, Pseudonym, Proposal, Digest, Vote, CastRecord


# BraidChain and BallotBox methods must be designed in a way to keep invariants for auditing.

"""
    struct BraidChainArchive
        ledger::Vector{Transaction}
    end

Represents a braidchain ledger archive. 
"""
struct BraidChainArchive
    ledger::Vector{Transaction}
#    guardian::Pseudonym
end

Base.length(archive::BraidChainArchive) = length(archive.ledger)

"""
    struct BallotBoxArchive
        proposal::Proposal
        seed::Digest
        ledger::Vector{CastRecord}
    end

Represents a ballotbox ledger archive. Contains a `proposal` for which votes have been collected; 
`seed` initialized by collector and `ledger` containing all cast records.
"""
struct BallotBoxArchive
    proposal::Proposal
    seed::Digest
    ledger::Vector{CastRecord}
    #groupSize::Int # This is already within an anchor state
end


Base.length(archive::BallotBoxArchive) = length(archive.ledger)

"""
    archive(ledger::BraidChain)::BraidChainArchive
    archive(ledger::BallotBox)::BallotBoxArchive

Form an archive of braidchain or ballotbox which can be sent over wire to be audited. 
"""
function archive end 



# Single ballotbox checksum should be enough


"""
    checksum(ledger::Union{BraidChainArchive, BallotBoxArchive}, hasher)::Digest

Calculate a history tree root from a given ledger records. Meant to be used to check integrity
of the received data. 
"""
function checksum end


"""
    audit_braids(ledger::BraidChainArchive)

Individually check every braid and it's zero knowledge proof and it's consistency with the chain. 
For the latter, that input pseudonyms and relative generator to a braid come from a previous output 
braiding output and newly registered members. 
"""
function audit_braids end

"""
    audit_members(ledger::BraidChainArchive)

Check every member registration certificate consistency with the ledger. In particular:
    - Admission approved by a trusted entity at that time;
    - Member approved by a admitted identity only once;
    - Every member psuedonym is generated with the current relative generator in the braidchain ledger;
"""
function audit_members end

"""
    audit_lots(ledger::BraidChainArchive)

Check integrity correct nonce commitments. Note that it is possible that this will be moved out 
to a ballotbox ledger in the future. Also service like DRAND would be beneficial to reduce trust
assumptions.
"""
function audit_lots end


"""
    audit_roster(ledger::BraidChainArchive)

Check that every `DemeSpec` transaction in the ledger is correctly signed by the guardian.  
"""
function audit_roster end


"""
    audit_proposals(ledger::BraidChainArchive)

Check every proposal for it's consistency with the chain. In particular:
    - Every proposal is signed by a valid proposer at the time of inclusion in the ledger;
    - Anchor in within the proposal is consistent with the ledger; 
    - Every proposal has a unique UUID as well as it's title is 
      sufficiently different from previous ones;
"""
function audit_proposals end


"""
    audit(archive::BallotBoxArchive, spec::CryptoSpec)

Check that recorded votes are consistent with proposal ballot and that cryptographic signature 
of every recorded vote is correct. 
---

    audit(archive::BraidChainArchive)

Check that the braidchain ledger is consistent. Runs through 

    - [`audit_members`](@ref)
    - [`audit_braids`](@ref) 
    - [`audit_proposals`](@ref)
    - [`audit_roster`](@ref)
    - [`audit_lots`](@ref)

---

    audit(ballotbox_archive::BraidChainArchive, ballotbox_archive::BallotBoxArchive, hasher)

Audits each ledger seperatelly and then checks consistency between themselves: such as that only valid
member pseudonyms have cast their votes, that proposal is available in the braidchain ledger.
    
"""
function audit end 

end
