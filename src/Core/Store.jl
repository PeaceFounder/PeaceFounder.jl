module Store

using Tar
using ShuffleProofs: ShuffleProofs
using ..Model: BraidChainLedger, DemeSpec, Membership, BraidReceipt, Proposal, Transaction, BallotBoxLedger, CastRecord, Seal, Termination
using ..Parser: marshal, unmarshal

index2name(i::UInt16) = reinterpret(UInt8, [i]) |> reverse |> bytes2hex |> uppercase
index2name(i::Int) = index2name(UInt16(i))

#index_name(i::Int) = reinterpret(UInt8, [UInt16(i)]) |> reverse |> bytes2hex |> uppercase

name2index(name::String) = reinterpret(UInt16, reverse(name |> hex2bytes))[1]

# I could simply use constants here

const DEMESPEC_DIR = "demespecs"
const MEMBERSHIP_DIR = "memberships"
const BRAIDRECEIPT_DIR = "braidreceipts"
const PROPOSAL_DIR = "proposals"
const TERMINATION_DIR = "terminations"
const CASTRECORD_DIR = "votes"

directory(::Type{DemeSpec}) = DEMESPEC_DIR
directory(::Type{Membership}) = MEMBERSHIP_DIR
direcotry(::Type{BraidReceipt}) = BRAIDRECEIPT_DIR
directory(::Type{Proposal}) = PROPOSAL_DIR
directory(::Type{Termination}) = TERMINATION_DIR

directory(::T) where T <: Transaction = directory(T)


function save(record::Union{DemeSpec, Membership, Proposal, Termination}, path::String; force=false)

    if isfile(path) 
        if force
            rm(path)
        else
            error("$path already exists; use `force` to overwrite.")
        end
    end
    
    open(path, "w") do file
        marshal(file, record)
    end
    
    return
end

function save(record::Union{DemeSpec, Membership, Proposal, Termination}, dir::String, index::Int; force=false)
    
    path = joinpath(dir, directory(record), index2name(index)) * ".json"
    mkpath(dirname(path))
    save(record, path; force)
   
    return
end

function save(record::BraidReceipt, dir::String; force=false)

    if isdir(dir) 
        if force
            rm(dir, recursive=true)
        else
            error("$dir already exists; use `force` to overwrite.")
        end
    end

    #mkdir(dir)
    mkpath(dir)

    open(joinpath(dir, "demespec.json"), "w") do file
        marshal(file, record.producer)
    end

    open(joinpath(dir, "metadata.json"), "w") do file
        marshal(file, (; seal = record.approval, reset = record.reset))
    end
    
    mkdir(joinpath(dir, "braid"))

    ShuffleProofs.save(record.braid, joinpath(dir, "braid"))
    
    return
end


function save(record::BraidReceipt, dir::String, index::Int; force=false)

    path = joinpath(dir, BRAIDRECEIPT_DIR, index2name(index))
    save(record, path; force)
    
end

function load(::Type{BraidReceipt}, dir::String)

    braid = ShuffleProofs.load(joinpath(dir, "braid"))
    spec = unmarshal(read(joinpath(dir, "demespec.json")), DemeSpec)
    (; seal, reset) = unmarshal(read(joinpath(dir, "metadata.json")), @NamedTuple{seal::Seal, reset::Bool})

    return BraidReceipt(braid, reset, spec, seal)
end

load(::Type{BraidReceipt}, dir::String, index::UInt16) = load(BraidReceipt, joinpath(dir, BRAIDRECEIPT_DIR, index2name(index)))


struct TarPath <: ShuffleProofs.Path
    io::IO
    path::String
end

function tar(io::IO, path::String, data::Vector{UInt8}; mode::Integer=0o644)
    
    n = length(data)

    Tar.write_header(io, Tar.Header(path, :file, mode, n, ""))
    Tar.write_data(io, IOBuffer(data), size=n)

end

Base.joinpath(path::TarPath, args...) = TarPath(path.io, joinpath(path.path, args...))
Base.mkdir(path::TarPath) = nothing
Base.mkpath(path::TarPath) = nothing
Base.write(path::TarPath, data::Vector{UInt8}) = tar(path.io, path.path, data)


function tar(io::IO, record::BraidReceipt)

    ShuffleProofs.save(record.braid, TarPath(io, "braid"))    
    tar(io, "demespec.json", marshal(record.producer))
    tar(io, "metadata.json", marshal((; seal = record.approval, reset = record.reset)))

    return
end

function load(::Type{BraidReceipt}, io::IO) 
    
    dir = joinpath(tempdir(), "braidreceipt")
    rm(dir, force=true, recursive=true)

    Tar.extract(io, dir)

    return load(BraidReceipt, dir)
end


function save(record::CastRecord, path::String; force=false)
    
    if isfile(path) 
        if force
            rm(path)
        else
            error("$path already exists; use `force` to overwrite.")
        end
    end

    mkpath(dirname(path))
    
    open(path, "w") do file
        marshal(file, record)
    end

    return
end


function save(record::CastRecord, dir::String, index::Int; force=false)

    path = joinpath(dir, CASTRECORD_DIR, index2name(index)) * ".json"
    save(record, path; force)
    
end


function save(ledger::BraidChainLedger, dest::String; force=false)

    if isdir(dest)
        if force
            rm(dest, recursive=true)
        else
            error("$dest already exists; use `force` to overwrite.")
        end
    end

    mkpath(dest)

    mkdir(joinpath(dest, DEMESPEC_DIR))
    mkdir(joinpath(dest, MEMBERSHIP_DIR))
    mkdir(joinpath(dest, BRAIDRECEIPT_DIR))
    mkdir(joinpath(dest, PROPOSAL_DIR))
    mkdir(joinpath(dest, TERMINATION_DIR))

    for (index, record) in enumerate(ledger)
        save(record, dest, index)
    end

    return
end


function save(ledger::BallotBoxLedger, dest::String; force=false)

    if isdir(dest)
        if force
            rm(dest, recursive=true)
        else
            error("$dest already exists; use `force` to overwrite.")
        end
    end

    mkpath(dest)

    mkdir(joinpath(dest, CASTRECORD_DIR))
    save(ledger.proposal, joinpath(dest, "proposal.json"))
    save(ledger.spec, joinpath(dest, "demespec.json"))
    
    for (index, record) in enumerate(ledger)
        save(record, dest, index)
    end

    return
end


function readkeys(path)

    list_str = readdir(path)
    list_int = UInt16[splitext(i)[1] |> name2index for i in list_str]
    sort!(list_int)

    return list_int
end


is_braidchain_path(dir) = isdir(joinpath(dir, DEMESPEC_DIR)) && isdir(joinpath(dir, MEMBERSHIP_DIR)) && isdir(joinpath(dir, BRAIDRECEIPT_DIR)) && isdir(joinpath(dir, PROPOSAL_DIR))

is_ballotbox_path(dir) = isdir(joinpath(dir, CASTRECORD_DIR)) && isfile(joinpath(dir, "demespec.json")) && isfile(joinpath(dir, "proposal.json"))


function load(dir::String)
    
    if is_braidchain_path(dir)
        return load_braidchain(dir)
    elseif is_ballotbox_path(dir)
        return load_ballotbox(dir)
    else
        error("Direcotry $dir does not point to either BraidChainLedger or BallotBoxLedger.")
    end
    
end


# I will do if else on direcotry structure so the API could remain simple
function load_braidchain(dir::String)

    demespec_keys = readkeys(joinpath(dir, DEMESPEC_DIR))
    membership_keys = readkeys(joinpath(dir, MEMBERSHIP_DIR))
    braidreceipt_keys = readkeys(joinpath(dir, BRAIDRECEIPT_DIR))
    proposal_keys = readkeys(joinpath(dir, PROPOSAL_DIR))
    termination_keys = readkeys(joinpath(dir, TERMINATION_DIR))

    _keys = [demespec_keys..., membership_keys..., braidreceipt_keys..., proposal_keys..., termination_keys...]

    ledger = BraidChainLedger(Transaction[])

    isempty(_keys) && return ledger

    #N = max(maximum(demespec_keys), maximum(membership_keys), 
    #maximum(braidreceipt_keys), maximum(proposal_keys))

    N = maximum(_keys)

    local record::Transaction

    for i::UInt16 in 1:N
        
        if i in demespec_keys
            bytes = read(joinpath(dir, DEMESPEC_DIR, index2name(i)) * ".json")
            record = unmarshal(bytes, DemeSpec)
        elseif i in membership_keys
            bytes = read(joinpath(dir, MEMBERSHIP_DIR, index2name(i)) * ".json")
            record = unmarshal(bytes, Membership)
        elseif i in braidreceipt_keys
            record = load(BraidReceipt, dir, i)
        elseif i in proposal_keys
            bytes = read(joinpath(dir, PROPOSAL_DIR, index2name(i)) * ".json")
            record = unmarshal(bytes, Proposal)
        elseif i in termination_keys
            bytes = read(joinpath(dir, TERMINATION_DIR, index2name(i)) * ".json")
            record = unmarshal(bytes, Termination)            
        else
            error("Entry $(Int(i)) not found in ledger with length $N")
        end

        push!(ledger, record)
    end
    
    return ledger
end


function load_ballotbox(dir::String)

    vote_keys = readkeys(joinpath(dir, CASTRECORD_DIR))

    demespec = unmarshal(read(joinpath(dir, "demespec.json")), DemeSpec)
    proposal = unmarshal(read(joinpath(dir, "proposal.json")), Proposal)

    ledger = BallotBoxLedger(CastRecord[], proposal, demespec)
    isempty(vote_keys) && return ledger

    N = maximum(vote_keys)

    for i::UInt16 in 1:N
        
        if i in vote_keys
            
            bytes = read(joinpath(dir, CASTRECORD_DIR, index2name(i)) * ".json")
            record = unmarshal(bytes, CastRecord)
            push!(ledger, record)

        else
            error("Entry $(Int(i)) not found in ledger with length $N")
        end

    end

    return ledger
end


end
