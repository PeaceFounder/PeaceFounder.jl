import Base.Dict

function Dict(id::PFID)
    dict = Dict()
    
    dict["name"] = id.name
    dict["date"] = id.date
    dict["id"] = string(id.id,base=16)
    
    return dict
end

function PFID(dict::Dict)
    name = dict["name"]
    date = dict["date"]
    id = ID(parse(BigInt,dict["id"],base=16))
    
    return PFID(name,date,id)
end

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
    ids = Any[ID(parse(BigInt,i,base=16)) for i in dict["ids"]] ### Any until I fix SynchronicBallot
    return Braid(nothing,nothing,ids)
end
