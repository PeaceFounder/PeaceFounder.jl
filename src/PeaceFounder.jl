module PeaceFounder

# A patch to make JSON3 to work with BigInt
Base.split_sign(x::BigInt) = (x, x<0) 

export Model, Mapper, Service, Client, Schedulers

# Beacons, Ballots could be defined in seperate components as well

function record! end

function commit! end



include("Utils/StaticSets.jl")
import .StaticSets

include("Model/Model.jl")
import .Model

include("Controllers/RegistrarController.jl")
import .RegistrarController

include("Controllers/BraidChainController.jl")
import .BraidChainController

include("Utils/Schedulers.jl")
import .Schedulers

include("Utils/Authorization.jl")
import .Authorization

include("Mapper.jl")
import .Mapper

include("Parser.jl")
import .Parser

include("Service.jl")
import .Service

include("Client.jl")
import .Client

include("AuditTools.jl")
import .AuditTools


end 
