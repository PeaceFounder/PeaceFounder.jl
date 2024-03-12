using Test
import PeaceFounder: Model, Parser, RegistrarController
import .Model: TicketID, Digest, Pseudonym, Admission, Seal, DemeSpec, CryptoSpec, Membership, Signature, Generator, id, HashSpec
import .RegistrarController: Invite
import .Parser: marshal, unmarshal
import Dates: DateTime, now
import URIs: URI


isconsistent(event::T) where T = unmarshal(marshal(event), T) == event

roundtrip(event::T) where T = unmarshal(marshal(event), T)

event = (TicketID("Alice"), now(), Digest(UInt8[1, 2, 3, 4]))
@test isconsistent(event)

event = (UInt8[2, 3, 4, 5], UInt8[2, 3, 4, 5], Digest(UInt8[1, 2, 3, 4, 5]))
@test isconsistent(event)

event = (Pseudonym(UInt8[1, 2, 3, 4]), Digest(UInt8[1, 2, 3, 4, 5]))
@test isconsistent(event)

admission = Admission(TicketID("Alice"), Pseudonym(UInt8[1, 2, 3, 4]), Seal(Pseudonym(UInt8[1, 2, 3, 4]), now(), Signature(123, 4345)))
@test isconsistent(admission)

event = Seal(Pseudonym(UInt8[1, 2, 3, 4]), now(), Signature(123, 4345))
@test isconsistent(event)

@test isconsistent(Model.CryptoSpec("sha256", "EC: P_192"))
@test isconsistent(Model.CryptoSpec("sha256", "MODP: 23, 11, 2"))

crypto = Model.CryptoSpec("sha256", "MODP: 23, 11, 2")
SIGNER = Model.generate(Model.Signer, crypto)
event = DemeSpec(;
                    uuid = Base.UUID(121432),
                    title = "A local democratic communituy",
                    email = "guardian@peacefounder.org",
                    crypto = crypto,
                    recorder = id(SIGNER),
                    registrar = id(SIGNER),
                    braider = id(SIGNER),
                    proposer = id(SIGNER),
                    collector = id(SIGNER)
) |> Model.approve(SIGNER) 
@test isconsistent(event)

event = Membership(admission, Generator(UInt8[1, 2, 3, 4]), Pseudonym(UInt8[1, 2, 3, 4]), Signature(123, 4242))
@test isconsistent(event)

event = Pseudonym(UInt8[1, 2, 3, 4])
@test isconsistent(event)

invite = Invite(Digest(rand(UInt8, 32)), rand(UInt8, 8), HashSpec("sha256"), URI("http://peacefounder.org"))
@test isconsistent(invite)

invite = Invite(Digest(rand(UInt8, 32)), rand(UInt8, 8), HashSpec("sha256"), URI())
@test isconsistent(invite)
