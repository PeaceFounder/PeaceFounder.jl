module PeaceFounder

# A patch to make JSON3 to work with BigInt
Base.split_sign(x::BigInt) = (x, x<0) 

# Can't export Core
# export Core, Server, Client

# The Core is a module that the minimum to be able to audit the evidence. The Server on the other hand is concerned with serving a service and recording new transactions which maintain integrity specified within the Model. The Client depends only on the Core and Authorization.

include("Core/Core.jl")
import .Core

include("Utils/StaticSets.jl") 
import .StaticSets

include("Utils/Schedulers.jl") 
import .Schedulers

include("Utils/Authorization.jl") # Client, Server
import .Authorization

include("Utils/TempAccessCodes.jl") # Server
import .TempAccessCodes

include("Utils/Base32.jl") # Server
import .Base32

include("Server/Server.jl")
import .Server

include("Client.jl") # Note that Client only depends on the Core and Authorization
import .Client


end 
