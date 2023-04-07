using Test
import PeaceFounder: Model, Parser
import .Model: TicketID, Digest, Pseudonym, Admission, Seal, DemeSpec, CryptoSpec, Member, Signature, Generator, id
import .Parser: marshal, unmarshal
import Dates: DateTime, now

isconsistent(event::T) where T = unmarshal(marshal(event), T) == event

roundtrip(event::T) where T = unmarshal(marshal(event), T)

event = (TicketID("Alice"), now(), Digest(UInt8[1, 2, 3, 4]))
@test isconsistent(event)

event = (UInt8[2, 3, 4, 5], UInt8[2, 3, 4, 5], Digest(UInt8[1, 2, 3, 4, 5]))
@test isconsistent(event)

event = (Pseudonym(UInt8[1, 2, 3, 4]), Digest(UInt8[1, 2, 3, 4, 5]))
@test isconsistent(event)

admission = Admission(TicketID("Alice"), Pseudonym(UInt8[1, 2, 3, 4]), now(), Seal(Pseudonym(UInt8[1, 2, 3, 4]), Signature(123, 4345)))
@test isconsistent(admission)

event = Seal(Pseudonym(UInt8[1, 2, 3, 4]), 2, 4)
@test isconsistent(event)

crypto = Model.CryptoSpec("SHA-256", "MODP", UInt8[1, 2, 3, 6])
SIGNER = Model.generate(Model.Signer, crypto)
event = DemeSpec(;
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    crypto = crypto,
                    guardian = id(SIGNER),
                    recorder = id(SIGNER),
                    recruiter = id(SIGNER),
                    braider = id(SIGNER),
                    proposer = id(SIGNER),
                    collector = id(SIGNER)
) |> Model.approve(SIGNER) 
@test isconsistent(event)

event = Member(admission, Generator(UInt8[1, 2, 3, 4]), Pseudonym(UInt8[1, 2, 3, 4]), Signature(123, 4242))
@test isconsistent(event)
