import ..Core.Parser

key_path(store::AccountStore) = store.key * ".json"
base_path(store::AccountStore) = store.base

index_string(i::Int) = bytes2hex(reinterpret(UInt8, [i])[1:2] |> reverse)

function string2index(hex_str::AbstractString)
    # Convert hex string back to bytes
    bytes = hex2bytes(hex_str)
    # Reverse the bytes to their original order
    reversed_bytes = reverse(bytes)
    # Combine the bytes to form the integer
    i = 0
    for (index, byte) in enumerate(reversed_bytes)
        i += byte << ((index - 1) * 8)
    end
    return i
end

function store!(store::AccountStore, spec::DemeSpec) 

    #tstamp = Dates.format(spec.seal.timestamp, "yyyy-mm-ddTHH:MM")    
    tstamp = Dates.format(spec.seal.timestamp, "yyyy-mm-dd_HH-MM")    

    path = joinpath(base_path(store), "demespec_$tstamp.json")

    isfile(path) && return

    mkpath(dirname(path))
    
    open(path, "w") do file
        Parser.marshal(file, spec)
    end

    return
end

# Loading one file is temporary
function load(store::AccountStore, ::Type{DemeSpec})

    spec_files = filter(startswith("demespec_"), readdir(base_path(store)))
    sort!(spec_files) # by filename

    spec_path = joinpath(base_path(store), spec_files[end])

    return Parser.unmarshal(read(spec_path), DemeSpec)
end


function store!(store::AccountStore, invite::Invite)

    path = joinpath(base_path(store), "registration", "invite.json")

    mkpath(dirname(path))

    rm(path, force=true)

    open(path, "w") do file
        write(file, string(invite))
    end

    return
end

function load(store::AccountStore, ::Type{Invite})

    path = joinpath(base_path(store), "registration", "invite.json")

    return Parser.unmarshal(read(path) |> String, Invite)
end

function store!(store::AccountStore, signer::Signer)

    path = key_path(store)

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, signer)
    end

    return
end

function load(store::AccountStore, ::Type{Signer})

    path = key_path(store)

    return Parser.unmarshal(read(path), Signer)
end


function store!(store::AccountStore, admission::Admission)

    path = joinpath(base_path(store), "registration", "admission.json")

    open(path, "w") do file
        Parser.marshal(file, admission)
    end

    return
end

# An opporunity to make it more DRY
function load(store::AccountStore, ::Type{Admission})
    
    path = joinpath(base_path(store), "registration", "admission.json")

    return Parser.unmarshal(read(path), Admission)
end


function store!(store::AccountStore, membership::Membership)

    #tstamp = Dates.format(membership.approval.timestamp, "yyyy-mm-ddTHH:MM")    
    tstamp = Dates.format(membership.approval.timestamp, "yyyy-mm-dd_HH-MM")    

    path = joinpath(base_path(store), "registration", "membership_$tstamp.json")

    open(path, "w") do file
        Parser.marshal(file, membership)
    end
    
    return
end


function load(store::AccountStore, ::Type{Membership})

    dir = joinpath(base_path(store), "registration")

    records = filter(startswith("membership_"), readdir(dir))
    sort!(records) # by filename

    return Parser.unmarshal(joinpath(dir, records[end]), Membership)
end


# Dispatch presumes that all acknowledgments are for registration
function store!(store::AccountStore, ack::AckInclusion{ChainState})

    store!(store, ack.commit)

    path = joinpath(base_path(store), "registration", "ack.json")

    open(path, "w") do file
        marshal(file, ack)
    end

    return
end


function load(store::AccountStore, ::Type{AckInclusion{ChainState}})

    path = joinpath(base_path(store), "registration", "ack.json")

    return Parser.unmarshal(path, AckInclusion{ChainState})
end


function store!(store::AccountStore, commit::Commit{ChainState})

    index = index_string(commit.state.index)
    #tstamp = Dates.format(commit.seal.timestamp, "yyyy-mm-ddTHH:MM")
    tstamp = Dates.format(commit.seal.timestamp, "yyyy-mm-dd_HH-MM")

    path = joinpath(base_path(store), "commits", "$(index)_$tstamp.json")

    isfile(path) && return

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, commit)
    end

    return
end


function load(store::AccountStore, ::Type{Commit{ChainState}})

    dir = joinpath(base_path(store), "commits")

    commit_path = joinpath(dir, sort(readdir(dir))[end])

    return Parser.unmarshal(read(commit_path), Commit{ChainState})
end


function load(store::AccountStore; server = nothing)
    
    spec = load(store, DemeSpec)
    signer = load(store, Signer)
    
    invite = load(store, Invite)
    admission = load(store, Admission)
    membership = load(store, Membership)
    ack = load(store, AckInclusion{ChainState})

    guard = EnrollGuard(admission, membership, ack)

    commit = load(store, Commit{ChainState})

    if isnothing(server)
        server = route(invite.route)
    end

    proposal_instances = ProposalInstance[]

    if isdir(joinpath(base_path(store), "proposals"))

        for dir in readdir(joinpath(base_path(store), "proposals"))
            proposal_store = joinpath(store, string2index(dir))
            instance = load(proposal_store)
            push!(proposal_instances, instance)
        end

    end

    return DemeAccount(spec, signer, guard, proposal_instances, commit, server, store)
end


function store!(store::ProposalStore, proposal::Proposal)

    path = joinpath(store.dir, "proposal.json")

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, proposal)
    end

    return
end

function load(store::ProposalStore, ::Type{Proposal})

    path = joinpath(store.dir, "proposal.json")

    return Parser.unmarshal(read(path), Proposal)
end


function store!(store::ProposalStore, ack::AckInclusion{ChainState})

    store!(store.account, ack.commit)

    path = joinpath(store.dir, "ack.json")

    open(path, "w") do file
        Parser.marshal(file, ack)
    end

    return
end

function load(store::ProposalStore, ::Type{AckInclusion{ChainState}})

    path = joinpath(store.dir, "ack.json")

    return Parser.unmarshal(read(path), AckInclusion{ChainState})
end


function store!(store::ProposalStore, vote::Vote)

    seq = UInt8(vote.seq) |> bytes2hex
    path = joinpath(store.dir, "casts", seq, "vote.json")

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, vote)
    end

    return
end


function load(store::ProposalStore, ::Type{Vote})

    cast_dir = joinpath(store.dir, "casts")
    isdir(cast_dir) || return 

    casts = sort(readdir(cast_dir))
    isempty(casts) && return

    vote_path = joinpath(cast_dir, casts[end], "vote.json")

    return Parser.unmarshal(read(vote_path), Vote)
end


function store!(store::ProposalStore, seq::Int, ack::CastAck)

    store!(store, ack.ack.commit)

    seq = UInt8(seq) |> bytes2hex
    path = joinpath(store.dir, "casts", seq, "ack.json")

    open(path, "w") do file
        Parser.marshal(file, ack)
    end

    return
end

function load(store::ProposalStore, ::Type{CastAck})

    cast_dir = joinpath(store.dir, "casts")
    isdir(cast_dir) || return 

    casts = sort(readdir(cast_dir))
    isempty(casts) && return

    ack_path = joinpath(cast_dir, casts[end], "ack.json")
    
    return Parser.unmarshal(read(ack_path), CastAck)
end


function store!(store::ProposalStore, commit::Commit{BallotBoxState})

    index = index_string(commit.state.index)
    #tstamp = Dates.format(commit.seal.timestamp, "yyyy-mm-ddTHH:MM")
    tstamp = Dates.format(commit.seal.timestamp, "yyyy-mm-dd_HH-MM")

    path = joinpath(store.dir, "commits", "$(index)_$tstamp.json")

    isfile(path) && return    

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, commit)
    end
    
    return
end

function load(store::ProposalStore, ::Type{Commit{BallotBoxState}})

    dir = joinpath(store.dir, "commits")

    isdir(dir) || return

    commit_path = joinpath(dir, sort(readdir(dir))[end])

    return Parser.unmarshal(read(commit_path), Commit{BallotBoxState})
end

function load(store::ProposalStore, ::Type{Commit{BallotBoxState}}, index::Int)

    dir = joinpath(store.dir, "commits")

    isdir(dir) || return

    commit_path = joinpath(dir, filter(startswith(index_string(index)), sort(readdir(dir)))[1])

    return Parser.unmarshal(read(commit_path), Commit{BallotBoxState})
end

function store!(store::ProposalStore, ack::AckConsistency{BallotBoxState})

    store!(store, ack.commit)
    store!(store, ack.commit.state.index, ack.proof)

    return
end

function load(store::ProposalStore, ::Type{AckConsistency{BallotBoxState}}, index::Int)

    result = load(store, ConsistencyProof, index)
    isnothing(result) && return
    proof, new_index = result

    commit = load(store, Commit{BallotBoxState}, new_index)

    return AckConsistency(proof, commit)
end


function store!(store::ProposalStore, commit_index::Int, proof::ConsistencyProof)

    commit_index == proof.index && return # The path for it is empty and thus is useless

    root_index_str = index_string(proof.index)
    commit_index_str = index_string(commit_index)
    
    path = joinpath(store.dir, "proofs", "$root_index_str-$commit_index_str.json")

    isfile(path) && return

    mkpath(dirname(path))

    open(path, "w") do file
        Parser.marshal(file, proof)
    end

    return
end


function load(store::ProposalStore, ::Type{ConsistencyProof}, index::Int)

    index_str = index_string(index)

    dir = joinpath(store.dir, "proofs")
    
    isdir(dir) || return nothing

    files = filter(startswith(index_str), readdir(dir))

    isempty(files) && return nothing
        
    if length(files) > 1
        @warn "More than one consitency file found matching `$(index_str)_*.json`"
    end

    fname = files[end]

    path = joinpath(dir, fname)

    proof = Parser.unmarshal(path, ConsistencyProof)

    next_index = split(first(splitext(fname)), "-") |> last |> string2index

    return proof, next_index
end


function load(store::ProposalStore)

    proposal = load(store, Proposal)
    ack = load(store, AckInclusion{ChainState})
    index = ack.proof.index

    commit = load(store, Commit{BallotBoxState})

    vote = load(store, Vote)
    if !isnothing(vote)
        ack_cast = load(store, CastAck)
        ack_integrity = AckConsistency{BallotBoxState}[]

        cast_index = ack_cast.ack.commit.state.index

        while !isnothing(begin proof = load(store, AckConsistency{BallotBoxState}, cast_index) end)
            
            push!(ack_integrity, proof)
            cast_index = proof.commit.state.index

        end

        blame = Blame[] # TODO

        guard = CastGuard(proposal, vote, ack_cast, ack_integrity, blame)
        seq = vote.seq
    else
        guard = nothing
        seq = 0
    end

    return ProposalInstance(index, proposal, ack, commit, guard, seq, store)
end


function load_client(dir::String; kwargs...)

    accounts = joinpath(dir, "accounts")
    keys = joinpath(dir, "keys")

    client = DemeClient(; dir)

    isdir(accounts) || return client

    for account_name in readdir(accounts)
        base_dir = joinpath(accounts, account_name)
        key_dir = joinpath(keys, account_name)

        store = AccountStore(base_dir, key_dir)

        account = load(store; kwargs...)

        push!(client.accounts, account)
    end

    return client
end
