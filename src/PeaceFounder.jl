module PeaceFounder

# A patch to make JSON3 to work with BigInt
Base.split_sign(x::BigInt) = (x, x<0) 

export Model, Mapper, Service, Client, Schedulers

# Beacons, Ballots could be defined in seperate components as well

include("Utils/StaticSets.jl")
using .StaticSets

include("Model/Model.jl")
using .Model

include("Utils/Schedulers.jl")
import .Schedulers

include("Utils/Authorization.jl")
import .Authorization

include("Mapper.jl")
using .Mapper

include("Parser.jl")
import .Parser

include("Service.jl")
using .Service

include("Client.jl")
using .Client

include("AuditTools.jl")
import .AuditTools


end 
