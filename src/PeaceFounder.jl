module PeaceFounder

# A patch to make JSON3 to work with BigInt
Base.split_sign(x::BigInt) = (x, x<0) 

export Model, Mapper, Service, Client, Schedulers


include("Model/Model.jl")
using .Model

include("Utils/Schedulers.jl")
import .Schedulers

include("Utils/AuditTools.jl")
import .AuditTools

include("Utils/Parser.jl")
import .Parser

include("Mapper.jl")
using .Mapper

include("Service.jl")
using .Service

include("Client.jl")
using .Client

end 
