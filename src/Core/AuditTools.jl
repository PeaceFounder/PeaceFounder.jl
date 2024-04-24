"""
After ellections have ended the collector publishes a tally. To assert that votes have been 
accuratelly counted and that only legitimate voters have participated an audit takes place.

Every voter after ellections receives a final tally together with a consistency proof 
which proves that their vote is included in the ledger which have produced the tally. 
From the voter client voter reads four important parameters for the ballotbox:

- `deme_uuid`: an UUID of the deme where the proposal is registered;
- `proposal_index`: a index at which the proposal is recorded in the braidchain ledger;
- `ledger_length`: a number of collected votes in the ledger;
- `ledger_root`: a ballotbox ledger root checksum.

The auditor also knows a `hasher` deme uses to make checksums which is immutable at the
moment deme is created.

Let's consider abstract functions to retrieve ballotbox and braidchain ledger archives from
the internet with `get_ballotbox_archive` and `get_braidchain_archive` then the auditing
can be done with a following script:

    braidchain_archive = get_ballotbox_archive(uuid)
    ballotbox_archive = get_ballotbox_archive(uuid, proposal_index)[1:ledger_length]

    @test checksum(ballotbox_archive, hasher) == ledger_root
    @test isbinding(braidchain_archive, ballotbox_archive, hasher)
    
    spec = crypto(braidchain_archive)
    
    @test audit(ballotbox_archive, spec)
    @test audit(braidchain_archive)

    @show tally(ballotbox_archive)

Note that `spec` is read from the `DemeSpec` record in the braidchain which can be trusted as 
the tree braidchain ledger checksum is listed within a proposal's anchor. The proposal is 
the first record in history tree for the ballotbox thus it is bound to `ledger_root` 
checksum and so demespec record is also tied to `ledger_root`.

For convinience an `audit` method is provided which audits both archives at the same time:

    audit(ledger::BraidChainLedger)
    audit(ledger::BallotBoxLedger)

    isbinding(bbox::BallotBoxLedger, commit::Commit{BallotBoxState})
    isbinding(ledger::BraidChainLedger, commit::Commit{ChainState})

    isbinding(chain::BraidChainLedger, bbox::BraidChainLedger)

    audit(chain::BraidChainLedger, bbox::BallotBoxLedger, commit::Commit{BallotBoxState})
    audit(chain::BraidChainLedger, bbox::BallotBoxLedger, root::Digest, N::Int = length(bbox))

Note that this audit does not check honesty of the `registrar` that it have admitted fake
users to gain more influence in the ellection result. Properties being verified by the audit:

- Legitimacy: only and all eligiable voters cast their votes;
- Fairness: every eligiable voter can vote at most once;
- Immutability: no vote can be deleted or modified when recorded in the ledger; 
- Tallied as Cast: all cast votes are counted honestly to predetermined procedure; 
- Software independence: the previously audited properties for the evidence does not 
depend on a trust in honest execution of peacefounder service nor honesty of the braiders
who provides new pseudonyms for the deme members. In other words the previously listed 
properties would not be altered if adversary would have a full control over the peacefounder 
service and the braiders. 

The immutability is ensured from voter's clients updating their consistency proof chain which includes their vote. If the vote gets removed from a chain every single voter who had cast their vote would get a proof for inconsistent ledger state called blame. The blame can be made public by the voter without revealing it's vote and thus ensures immutability and also persitance after votes are published. The auditable part here are the votes themselves signed with pseudonym which contract voter's clients to follow up at latter periods with consistency proofs. On top of that, other monitors can synchronize the ballotbox ledger and add assurances that way.

"""
module AuditTools

using ArgParse

# TODO: consider DRY

using ..Model: Model, Digest, BallotBoxLedger, BraidChainLedger, Commit, BallotBoxState, ChainState, DemeSpec

using ..Store: Store
using ..Parser: Parser


function parse_commandline()
    settings = ArgParseSettings()

    @add_arg_table! settings begin
        "root"
            help = "Calculates a tree root for ballotbox or braidchain ledger"
            action = :command
        "commit"
            help = "Performs an audit and checks that the commit state and it's issuer is binding; Shows a warning if commit index is smaller than that of ledger index"
            action = :command
        "tally"
            help = "Performs an audit of the ballotbox ledger and returns a tally;"
            action = :command
        "state"
            help = "Performs an audit of the braidchain ledger and returns audit summary; It is also possible to perform an audit up until a given chain index passed with -N;"
            action = :command
        "eligiability"
            help = "Checks if ballotbox have collected votes from eligiable voters as specified in proposal anchor; also checks that proposal and demespec is part of the braidchain;"
            action = :command
        "all"
            help = "Executes audit commit for braidchain and every ballotbox ledger and checks eligiability of every ballotbox"
            action = :command
    end

    @add_arg_table! settings["root"] begin
        "ledger"
            help = "Location of either braidchain or ballotbox ledger"
            required = true
        "--type"
            help = "Sets the ledger type; allowed values {automatic|braidchain|ballotbox}"
            default = "automatic"
        "--index"
            help = "Sets the index at which the root is calculated;"
            arg_type = Int
            default = 0 
    end

    @add_arg_table! settings["commit"] begin
        "ledger"
            help = "Location of either braidchain or ballotbox ledger"
            required = true
        "commit"
            help = "Location of ledger commit;"
            default = nothing
        "--type"
            help = "Sets the ledger type; allowed values {automatic|braidchain|ballotbox}"
            default = "automatic"
        "--trust-ledger"
            help = "Audits only the commit while assumes integrity of the ledger; Useful in monitoring scenarios when client forwards two inconsistent commits as a blame proof and thus auditing is not needed as that is done previously"
            action = :store_false
    end
    
    @add_arg_table! settings["tally"] begin
        "ballotbox"
            help = "Location of ballotbox ledger"
            required = true
        "--trust-ledger"
            help = "Only counts the votes without checking seals of the votes"
            action = :store_false
        "--index"
            help = "Sets the index at which the root is calculated;"
            arg_type = Int
            default = 0 
    end

    @add_arg_table! settings["state"] begin
        "braidchain"
            help = "Location of braidchain ledger"
            required = true
        "--index"
            help = "Sets the index at which the root is calculated;"
            arg_type = Int
            default = 0 
        "--trust-ledger"
            help = "Only produces the current state"
            action = :store_false
    end

    @add_arg_table! settings["eligiability"] begin
        "braidchain"
            help = "Location of braidchain ledger"
            required = true
        "ballotbox"
            help = "Location of ballotbox ledger"
            required = true
    end

    @add_arg_table! settings["all"] begin
        "buletinboard"
            help = "Location of braidchain ledger and ballotbox ledgers as generated by PeaceFounder in the public folder"
            required = true
        "--verbose"
            help = "Whether audit needs to be verbose"
            action = :store_true
    end

    return parse_args(settings)
end


function main()

    parsed_args = parse_commandline()

    cmd = parsed_args["%COMMAND%"]
    args = parsed_args[cmd]

    if cmd == "root"
        
        type = args["type"] == "automatic" ? get_ledger_type(args["ledger"]) : args["type"]
        index = args["index"] == 0 ? nothing : args["index"]

        if type == "ballotbox"
            return audit_root_ballotbox(args["ledger"]; index) |> exit
        elseif type == "braidchain"
            return audit_root_braidchain(args["ledger"]; index) |> exit
        else
            error("Unrecognized ledger type $type. Possible values {automatic|braidchain|ballotbox}")
        end

    elseif cmd == "commit"

        type = args["type"] == "automatic" ? get_ledger_type(args["ledger"]) : args["type"]

        if type == "ballotbox"
            return audit_commit_ballotbox(args["ledger"]; trust_ledger = args["trust-ledger"], commit = args["commit"]) |> exit
        elseif type == "braidchain"
            return audit_commit_braidchain(args["ledger"]; trust_ledger = args["trust-ledger"], commit = args["commit"]) |> exit
        else
            error("Unrecognized ledger type $type. Possible values {automatic|braidchain|ballotbox}")
        end

    elseif cmd == "tally"

        index = args["index"] == 0 ? nothing : args["index"]
        return audit_tally(args["ballotbox"]; trust_ledger = args["trust-ledger"], index) |> exit

    elseif cmd == "state"

        index = args["index"] == 0 ? nothing : args["index"]
        return audit_state(args["braidchain"]; index) |> exit

    elseif cmd == "eligiability"
        return audit_eligiability(args["braidchain"], args["ballotbox"]) |> exit
    elseif cmd == "all"
        return audit_all(args["buletinboard"]; verbose = args["verbose"]) |> exit
    else
        error("$cmd is not implemented although specified")
    end
end

# This module perhaps better to have it's own namespace

function chunk_string(s::String, chunk_size::Int)
    return join([s[i:min(i+chunk_size-1, end)] for i in 1:chunk_size:length(s)], "-")
end


function audit_root_braidchain(ledger::String; index=nothing) 

    ledger = Store.load_braidchain(ledger)
    
    N = isnothing(index) ? length(ledger) : index
    root = chunk_string(Model.root(ledger, N) |> string |> uppercase, 8)
    hasher = Model.hasher(ledger[1]) |> string 
    println("#$N:$hasher:$root")

    return 0
end


function audit_root_ballotbox(ledger::String; index=nothing) 

    ledger = Store.load_ballotbox(ledger)

    N = isnothing(index) ? length(ledger) : index
    root = chunk_string(Model.root(ledger, N) |> string |> uppercase, 8)
    hasher = Model.hasher(ledger.spec) |> string 
    println("⌘$N:$hasher:$root")

    return 0
end

function audit_commit_braidchain(ledger::String; commit=nothing, trust_ledger=false) 

    _ledger = Store.load_braidchain(ledger)

    commit_path = isnothing(commit) ? joinpath(ledger, "commit.json") : commit
    
    _commit = Parser.unmarshal(read(commit_path), Commit{ChainState})

    @assert length(_ledger) >= Model.index(_commit) "Ledger too short with $(length(_ledger)) records to audit commit with index $(index(_commit))"

    if !trust_ledger && length(_ledger) > Model.index(_commit)
        
        @warn "Commit index smaller than ledger; Ledger with $(length(_ledger)) records will be cut at $(index(_commit)) for the audit. If only commit is audited use `trust_ledger=true` argument"

    end

    Model.isbinding(_ledger, _commit) || return 1

    if !trust_ledger
        Model.audit(view(_ledger, 1:Model.index(_commit))) || return 1
    end

    return 0
end 


function audit_commit_ballotbox(ledger::String; commit=nothing, trust_ledger=false) 

    _ledger = Store.load_ballotbox(ledger)

    commit_path = isnothing(commit) ? joinpath(ledger, "commit.json") : commit

    _commit = Parser.unmarshal(read(commit_path), Commit{BallotBoxState}) 

    @assert length(_ledger) >= Model.index(_commit) "Ledger too short with $(length(_ledger)) records to audit commit with index $(index(_commit))"
    
    if !trust_ledger && length(_ledger) > Model.index(_commit)
        
        @warn "Commit index smaller than ledger; Ledger with $(length(_ledger)) records will be cut at $(index(_commit)) for the audit. If only commit is audited use `trust_ledger=true` argument"

    end

    Model.isbinding(_ledger, _commit) || return 1
    
    if !trust_ledger
        Model.audit(view(_ledger, 1:Model.index(_commit))) || return 1
    end
    
    return 0
end


function audit_tally(bbox::String; trust_ledger=false, index=nothing) 
    
    ledger = Store.load_ballotbox(bbox)

    index = isnothing(index) ? length(ledger) : index
    
    @assert length(ledger) >= index "Out of bounds: Ledger is of length $(length(_ledger)) wheras the index is $index"

    if !trust_ledger 
        Model.audit(view(ledger, 1:index)) || return 1
    end

    tally = Model.tally(view(ledger, 1:index))

    println(string(tally))
    
    return 0
end


function audit_state(chain::String; trust_ledger=false, index=nothing) 

    ledger = Store.load_braidchain(chain)

    index = isnothing(index) ? length(ledger) : index

    @assert length(ledger) >= index "Out of bounds: Ledger is of length $(length(_ledger)) wheras the index is $index"

    if !trust_ledger 
        Model.audit(view(ledger, 1:index)) || return 1
    end
    
    state = Model.state(ledger, index)

    println(string(state))
    
    return 0
end

function audit_eligiability(chain::String, bbox::String) 

    chain_ledger = Store.load_braidchain(chain)
    bbox_ledger = Store.load_ballotbox(bbox)

    Model.isbinding(chain_ledger, bbox_ledger) || return 1

    return 0
end


function audit_all(bboard::String; verbose=true) 

    status = 0

    chain_ledger = joinpath(bboard, "braidchain")
    bbox_dir = joinpath(bboard, "ballotboxes")

    verbose && println("Auditing BraidChain")

    audit_commit_braidchain(chain_ledger) == 0 || (status += 1)

    for bbox in readdir(bbox_dir)

        verbose && println("Processing ballotbox: $bbox")

        audit_commit_ballotbox(joinpath(bbox_dir, bbox)) == 0 || (status += 1)
        audit_eligiability(chain_ledger, joinpath(bbox_dir, bbox)) == 0 || (status += 1)

    end
    
    if status == 0
        verbose && println("Summary: Audit Sucesfull")
    else
        verbose && println("Summary: Audit had $status errrors")
    end
        
    return status
end


function get_ledger_type(dir::String) 

    if Store.is_braidchain_path(dir)
        return "braidchain"
    elseif Store.is_ballotbox_path(dir)
        return "ballotbox"
    else
        error("$dir is not either braidchain or ballotbox ledger")
    end

end


end
