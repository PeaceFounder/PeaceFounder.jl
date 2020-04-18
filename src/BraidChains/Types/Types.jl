module Types

using DemeNet: Certificate, Contract, Intent, Consensus, AbstractID, ID, DemeID, Deme
using PeaceVote.Plugins: AbstractVote, AbstractProposal, AbstractBraid, AbstractChain
using Sockets
using Base: UUID

using Recruiters: CertifierConfig
#import PeaceVote: load 

import Base.Dict

### Let's make stuff first for SystemConfig. 


### Perhaps I could introduce a Mixer subtype.


### 
struct Vote <: AbstractVote
    pid::Int ### One gets it from a BraidChain loking into a sealed proposal
    vote::Int ### Number or a message
end

struct Proposal <: AbstractProposal
    msg::AbstractString
    options::Vector{T} where T<:AbstractString
end

import Base.==
==(a::Proposal,b::Proposal) = a.msg==b.msg && a.options==b.options

### The main task of this type is to have enough information to 
### establish the trust.
# struct PFID <: AbstractID
#     name::AbstractString
#     date::AbstractString
#     id::ID
# end

struct Braid <: AbstractBraid
    index::Union{Nothing,Int} ### latest index of the ledger
    hash::Union{Nothing,BigInt} ### hash of the ledger up to the latest index
    ids::Vector{ID} ### the new ids for the public keys
end


struct BraidChain <: AbstractChain
    deme::Deme
    ledger
end



import Base.Dict

# function Dict(id::PFID)
#     dict = Dict()
    
#     dict["name"] = id.name
#     dict["date"] = id.date
#     dict["id"] = string(id.id,base=16)
    
#     return dict
# end

# function PFID(dict::Dict)
#     name = dict["name"]
#     date = dict["date"]
#     id = ID(parse(BigInt,dict["id"],base=16))
    
#     return PFID(name,date,id)
# end

function Dict(p::Proposal)
    dict = Dict()
    dict["msg"] = p.msg
    dict["options"] = p.options
    return dict
end

function Proposal(dict::Dict)
    msg = dict["msg"]
    options = dict["options"]
    return Proposal(msg,options)
end

function Dict(v::Vote)
    dict = Dict()
    dict["pid"] = v.pid
    dict["vote"] = v.vote
    return dict
end

function Vote(dict::Dict)
    pid = dict["pid"]
    vote = dict["vote"]
    return Vote(pid,vote)
end

function Dict(braid::Braid)
    dict = Dict()
    dict["ids"] = [string(i.id,base=16) for i in braid.ids]
    return dict
end

function Braid(dict::Dict)
    ids = ID[ID(parse(BigInt,i,base=16)) for i in dict["ids"]] ### Any until I fix SynchronicBallot
    return Braid(nothing,nothing,ids)
end








#include("systemconfig.jl")
#include("chaintypes.jl")

### At this point I may be able to define how the files should look like

#export connect, listen, Port

end
