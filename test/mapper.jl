using Test

import PeaceFounder.Model
import PeaceFounder.Mapper
using PeaceFounder.Model: Crypto, gen_signer, pseudonym, TicketID, Member, Proposal, Ballot, Selection, generator, state, id, vote, seed, tally, approve, istallied

import Dates: Dates, Date

crypto = Crypto("SHA-256", "MODP", UInt8[1, 2, 3, 6])
GUARDIAN = gen_signer(crypto)

Mapper.setup!(GUARDIAN)


function enroll!(signer, token)

    admission = Mapper.seek_admission!(id(signer), token)
    
    commit = Mapper.get_chain_commit()
    g = generator(commit)
    access = approve(Member(admission, g, pseudonym(signer, g)), signer)

    ack = Mapper.submit_chain_record!(access)
    
    return access, ack
end


token = Mapper.submit_ticket!(TicketID("Alice"))
alice = gen_signer(crypto)
access, ack = enroll!(alice, token)

token = Mapper.submit_ticket!(TicketID("Bob"))
bob = gen_signer(crypto)
access, ack = enroll!(bob, token)

token = Mapper.submit_ticket!(TicketID("Eve"))
eve = gen_signer(crypto)
access, ack = enroll!(eve, token)


status = Mapper.get_ticket_status(TicketID("Alice")) # :registered, 
admission = Mapper.get_ticket_admission(TicketID("Alice"))

commit = Mapper.get_chain_commit()

proposal_draft = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Are you ready for democracy?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = Dates.now(),
    closed = Dates.now() + Dates.Second(1),
    collector = id(GUARDIAN),

    state = state(commit)
)

proposal = approve(proposal_draft, GUARDIAN)

# I could also improve matters here
ack = Mapper.submit_chain_record!(proposal) # I could integrate ack 
# A lot of stuff going behind the scenes here regarding the dealer and etc
member_list = Mapper.get_chain_roll()

record = Mapper.get_chain_record(2)
ack_leaf = Mapper.get_chain_ack_leaf(2)
ack_root = Mapper.get_chain_ack_root(2)


proposal_list = Mapper.get_chain_proposal_list()
N, proposal = proposal_list[1]

@test Model.isopen(proposal; time = proposal.open + Dates.Millisecond(100)) # Need to implement. Checks whether proposal is open

Mapper.dealer_process_loop(force = true)

commit = Mapper.get_ballotbox_commit(proposal.uuid)
_seed = seed(commit)

v = vote(proposal, _seed, Selection(2), alice)

ack = Mapper.cast_vote!(proposal.uuid, v)

v = vote(proposal, _seed, Selection(1), bob)
ack = Mapper.cast_vote!(proposal.uuid, v)

v = vote(proposal, _seed, Selection(1), eve)
ack = Mapper.cast_vote!(proposal.uuid, v)


spine = Mapper.get_ballotbox_spine(proposal.uuid)

#Mapper.tally_votes!(proposal.uuid)

ballotbox = Mapper.ballotbox(proposal.uuid)
@test istallied(ballotbox) == false
sleep(1)
@test istallied(ballotbox) == true

# auditing phase

chain_commit = Mapper.get_chain_commit();
# chain_archive = Mapper.get_chain_archive() # could have a seperate direcotry for braids

# AuditTools.audit_tree(chain_archive, chain_commit) 
# AuditTools.audit_members(chain_archive)
# AuditTools.audit_proposals(chain_archive)
# AuditTools.audit_lots(chain_archive)

# ballotbox_commit = Mapper.get_ballotbox_commit(proposal.uuid)
# ballotbox_archive = Mapper.get_ballotbox_archive(proposal.uuid) # contains a proposal, seed and ledger

# @test isbinding(ballotbox_archive, chain_archive) # tests proposal and the seed, teh coresponding lot

# AuditTools.audit_tree(ballotbox_archive, ballotbox_commit)
# AuditTools.audit_votes(ballotbox_archive, ballotbox_commit)
# AuditTools.tally(ballotbox_archive, ballotbox_commit) 

