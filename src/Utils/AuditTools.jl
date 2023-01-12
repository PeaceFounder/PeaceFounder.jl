module AuditTools

using ..Model: Transaction, Pseudonym, Proposal, Digest, Vote


# BraidChain and BallotBox methods must be designed in a way to keep invariants for auditing.

struct BraidChainArchive
    ledger::Vector{Transaction}
    guardian::Pseudonym
end

struct BallotBoxArchive
    proposal::Proposal
    seed::Digest
    ledger::Vector{Vote}
end


"""
Forms an archive of braidchain or ballotbox which can be sent over wire or audited.
"""
function archive end 


"""
Checks that the tree is consistent with gvien root at given length. Also relevant to ballotbox. If commitment is passed requires it to be at the same length
"""
function audit_tree end

"""
Checks that data with in commitment state is consistent with the chain. Used to check that the guardian is answering to client state requests honestly and have not deviated from that. Cleints could for instance chekc consistency proof. Also relevant to ballotbox. 

Could accpet a vector of commits
"""
function audit_commit end


"""
Individually checks the proofs of the braids
"""
function audit_braids end

"""
Checks that:
    - Admission approved by a trusted entity at that time
    - Member approved by a trusted admission and only once.
    - Members generated with a correct generator
    - Validates braidchain reset and member unregistration actions.
"""
function audit_members end

"""
Checks the integrity of pulses and correct commitments of nonces.
"""
function audit_lots end


"""
Checks that ranks are correctly being assigned. Verifiers for audit_members chekks thoose things only narrowly checking who is elligiable to admit members at a given momment. Here it;s being checked who is issuing the rank.
"""
function audit_roster end


"""
Checks that added proposals are consistent with the chain. Proposals are unique. 
"""
function audit_proposals end


"""
Checks that
    - every vote is signed by a valid member signature
    - only increasing sequentual number votes are within the chain
"""
function audit_votes end

# a method on chain
# a method in ballotbox
# not together! `proposal(ballotbox) in chain` will need to be checked.
function audit end 

end
