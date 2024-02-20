using Test

import PeaceFounder.Model
import PeaceFounder.Mapper
using PeaceFounder.Model: CryptoSpec, pseudonym, TicketID, Member, Proposal, Ballot, Selection, generator, state, id, vote, seed, tally, approve, istallied, DemeSpec, hasher, HMAC, token, isbinding, Generator, generate, Signer, Invite, tokenid

import Dates: Dates, Date

crypto = CryptoSpec("sha256", "EC: P_192")
#crypto = CryptoSpec("sha256", "MODP: 23, 11, 2")

GUARDIAN = generate(Signer, crypto)
PROPOSER = generate(Signer, crypto)


Mapper.initialize!(crypto)

roles = Mapper.system_roles()

demespec = DemeSpec(;
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    crypto = crypto,
                    guardian = id(GUARDIAN),
                    recorder = roles.recorder,
                    registrar = roles.registrar,
                    braider = roles.braider,
                    proposer = id(PROPOSER),
                    collector = roles.collector
) |> approve(GUARDIAN) 


Mapper.capture!(demespec)

RECRUIT_AUTHORIZATION_KEY = Mapper.get_recruit_key() 
RECRUIT_HMAC = HMAC(RECRUIT_AUTHORIZATION_KEY, hasher(crypto))

#function enroll(signer, ticketid, token)

function enroll(signer, invite::Invite)

    # Authorization is done in the service layer now!
    # auth_code = auth(id(signer), invite.token, hasher(invite))

    _tokenid = tokenid(invite.token, invite.hasher)
    ticket = Mapper.get_ticket(_tokenid) # This is done at the service layer
    
    admission = Mapper.seek_admission(id(signer), ticket.ticketid)
    
    commit = Mapper.get_chain_commit()
    g = generator(commit)
    access = approve(Member(admission, g, pseudonym(signer, g)), signer)

    ack = Mapper.submit_chain_record!(access)
    
    return access, ack
end


ticketid_alice = TicketID("Alice")
invite_alice = Mapper.enlist_ticket(ticketid_alice)

ticketid_bob = TicketID("Bob")
invite_bob = Mapper.enlist_ticket(ticketid_bob)

ticketid_eve = TicketID("Eve")
invite_eve = Mapper.enlist_ticket(ticketid_eve)


alice = Signer(crypto, 2)
access_alice, ack = enroll(alice, invite_alice)

bob = Signer(crypto, 3)
access_bob, ack = enroll(bob, invite_bob)

eve = Signer(crypto, 4)
access_eve, ack = enroll(eve, invite_eve)

@test Mapper.get_ticket_status(ticketid_alice) isa Model.TicketStatus
@test Mapper.get_ticket_admission(ticketid_alice) isa Model.Admission

### Braiding

input_generator = Mapper.get_generator()
input_members = Mapper.get_members()

braidwork = Model.braid(input_generator, input_members, demespec, demespec, Mapper.BRAIDER[]) 

Mapper.submit_chain_record!(braidwork)

### 

commit = Mapper.get_chain_commit()

proposal = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban all personal vehicle usage and invest in alternative forms of transportation such as public transit, biking and walking infrastructure?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = Dates.now(),
    closed = Dates.now() + Dates.Second(2),
    collector = roles.collector,

    state = state(commit)
) |> approve(PROPOSER)


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

ack = Mapper.cast_vote(proposal.uuid, v)

v = vote(proposal, _seed, Selection(1), bob)
ack = Mapper.cast_vote(proposal.uuid, v)

v = vote(proposal, _seed, Selection(1), eve)
ack = Mapper.cast_vote(proposal.uuid, v)


spine = Mapper.get_ballotbox_spine(proposal.uuid)

#Mapper.tally_votes!(proposal.uuid)

ballotbox = Mapper.ballotbox(proposal.uuid)
@test istallied(ballotbox) == false
sleep(2)
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

