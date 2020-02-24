import Community
import Sockets
using PeaceVote
setnamespace(@__MODULE__)
uuid = PeaceVote.uuid("Community")

server = PeaceVote.Signer(uuid,"server")

println("The ID of the server key is:")
println("\t$(server.id)")

println("The IP address of the server:")
println("\t$(Sockets.getipaddr())")
