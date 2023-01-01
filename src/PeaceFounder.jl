module PeaceFounder

# A patch to make JSON3 to work with BigInt
Base.split_sign(x::BigInt) = (x, x<0) 

export Model, Mapper, Resource, Client


include("Model/Scheduler.jl")
import .Schedulers


include("Model/Model.jl")
using .Model

include("Mapper.jl")
using .Mapper

#include("Resource.jl")
#using .Resource

#include("Client.jl")
#using .Client


end 
