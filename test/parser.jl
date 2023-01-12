using Test
import PeaceFounder: Model, Parser
import .Model: TicketID, Digest, Pseudonym, Admission, Seal
import .Parser: marshal, unmarshal
import Dates: DateTime, now


event = (TicketID("Alice"), now(), Digest(UInt8[1, 2, 3, 4]))
@test unmarshal(marshal(event), Tuple{TicketID, DateTime, Digest}) == event

event = (UInt8[2, 3, 4, 5], Digest(UInt8[1, 2, 3, 4, 5]))
@test unmarshal(marshal(event), Tuple{Vector{UInt8}, Digest}) == event

event = (Pseudonym(UInt8[1, 2, 3, 4]), Digest(UInt8[1, 2, 3, 4, 5]))
@test unmarshal(marshal(event), Tuple{Pseudonym, Digest}) == event

event = Admission(TicketID("Alice"), Pseudonym(UInt8[1, 2, 3, 4]), now())
@test unmarshal(marshal(event), Admission) == event

event = Seal(Pseudonym(UInt8[1, 2, 3, 4]), 2, 4)
@test unmarshal(marshal(event), Seal) == event
