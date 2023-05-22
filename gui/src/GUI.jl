module GUI

using Dates: Dates, DateTime, TimePeriod
using Infiltrator
using PeaceFounder
using PeaceFounder: Client, Model, Parser
using QML

using Qt65Compat_jll
QML.loadqmljll(Qt65Compat_jll)

using Base: UUID
using .Client: DemeClient, DemeAccount, ProposalInstance
using .Model: Selection, Proposal


mutable struct DemeItem
    uuid::String
    title::String
    #commitIndex::Int # commitIndex
    memberCount::Int # groupSize
end


mutable struct ProposalItem
    index::Int # proposalIndex or simply index
    title::String
    voterCount::Int
    castCount::Int
    isVotable::Bool
    isCast::Bool
    isTallied::Bool
    timeWindow::String
end

mutable struct BallotQuestion
    question::String
    options::Vector{String}
    choice::Int
end


function select(predicate::Function, data::Vector)

    N = findfirst(predicate, data)

    @assert !isnothing(N) "No item with given predicate found"

    return data[N]
end

select(predicate::Function, model::QML.JuliaItemModelAllocated) = select(predicate, QML.get_julia_data(model).values[])


function reset!(lm, list)

    QML.begin_reset_model(lm)

    data = QML.get_julia_data(lm)

    empty!(data.values[])
    append!(data.values[], list)

    QML.end_reset_model(lm)

    return
end


function load_prototype()

    loadqml((@__DIR__) * "/../qml/Prototype.qml")
    exec()

    return
end

const USER_DEMES = JuliaItemModel(DemeItem[])

const DEME_STATUS = JuliaPropertyMap(
    "uuid" => "UNDEFINED",
    "title" => "Local democratic community",
    "demeSpec" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED",
    "memberIndex" => 21,
    "commitIndex" => 89,
    "memberCount" => 16
)

const DEME_PROPOSALS = JuliaItemModel(ProposalItem[])

const PROPOSAL_METADATA = JuliaPropertyMap(
    "index" => 0,
    "title" => "PROPOSAL TITLE",
    "description" => "PROPOSAL DESCRIPTION",
    "stateAnchor" => 0,
    "voterCount" => 0
)

const PROPOSAL_STATUS = JuliaPropertyMap(
    "isVotable" => false,
    "isCast" => false,
    "isTallied" => false,
    "timeWindowShort" => "HOURS Remaining",
    "timeWindowLong" => "HOURS remaining to cast your choice",
    "castCount" => 0
)

const PROPOSAL_BALLOT = JuliaItemModel(BallotQuestion[])

const GUARD_STATUS = JuliaPropertyMap(
    "pseudonym" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED",
    "timestamp" => "June 15, 2009 1:45 PM",
    "castIndex" => 0,
    "commitIndex" => 0,
    "commitRoot" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
)



function load_view(init::Function = () -> nothing)

    loadqml((@__DIR__) * "/../qml/Bridge.qml"; 
            _USER_DEMES = USER_DEMES,
            _DEME_STATUS = DEME_STATUS,
            _DEME_PROPOSALS = DEME_PROPOSALS,
            _PROPOSAL_METADATA = PROPOSAL_METADATA,
            _PROPOSAL_STATUS = PROPOSAL_STATUS,
            _PROPOSAL_BALLOT = PROPOSAL_BALLOT,
            _GUARD_STATUS = GUARD_STATUS
            )

    init()

    exec()

end



const CLIENT = DemeClient()


function item(account::DemeAccount)


    uuid = uppercase(string(account.deme.uuid))
    title = account.deme.title
    memberCount = account.commit.state.member_count # could shorten state(account).member_count

    return DemeItem(uuid, title, memberCount)
end



# The way to print out the interval is 
# more an UI decission. Although it could help improving 
# prining of a proposal and perhaps justify introducing TimeWindow type


function time_period(period::TimePeriod)

    if period < Dates.Second(90)

        seconds = div(period, Dates.Second(1))
        return "$seconds seconds"

    elseif period < Dates.Minute(90)

        minutes = div(period, Dates.Minute(1), RoundUp)
        return "$minutes minutes"

    elseif period < Dates.Hour(36)

        hours = div(period, Dates.Hour(1), RoundUp)
        return "$hours hours"

    else

        # Need to make it two days

        days = div(period, Dates.Day(1), RoundUp)
        return "$days days"

    end

end


function time_window(open::DateTime, closed::DateTime; time = Dates.now())

    if time < open
                
        period = open - time
        period_str = time_period(period)

        return "Opens in $period_str"

    elseif time > closed

        period = time - closed

        if period < Dates.Hour(12)

            period_str = time_period(period)
            return "Closed $period_str ago"

        else

            str = Dates.format(closed, Dates.dateformat"dd-u-yyyy")
            return "Closed on $str"

        end

    else 

        period = closed - time
        period_str = time_period(period)

        return "$period_str remaining"

    end
end


time_window(proposal::Proposal) = time_window(proposal.open, proposal.closed)



function item(instance::ProposalInstance)

    index = instance.index
    title = instance.proposal.summary
    voterCount = instance.proposal.anchor.member_count
    #castCount = isnothing(instance.commit) ? 0 : instance.commit.state.index
    castCount = isnothing(Model.commit(instance)) ? 0 : Model.commit(instance).state.index
    
    #isVotable = Client.isvotable(instance)
    isVotable = Client.isopen(instance)
    isTallied = Client.istallied(instance)
    isCast = !isnothing(instance.guard)
    timeWindow = time_window(instance.proposal)

    return ProposalItem(index, title, voterCount, castCount, isVotable, isCast, isTallied, timeWindow)
end

function ballot(instance::ProposalInstance)

    question = "" # Until ballot type gets fixed
    options = instance.proposal.ballot.options
    
    pushfirst!(options, "Not Selected")
    choice = 0 

    return BallotQuestion(question, options, choice)
end


function select(predicate::Function, collection::AbstractVector)

    for item in collection
        if predicate(item)
            return item
        end
    end

    return nothing
end


select(predicate::Function) = collection -> select(predicate, collection)


select(uuid::UUID, client::Client.DemeClient) = select(account -> account.deme.uuid == uuid, client.accounts)
select(uuid::AbstractString, client::Client.DemeClient) = select(UUID(uuid), client)

select(index::Integer, account::DemeAccount) = select(instance -> instance.index == index, account.proposals)
select(uuid::UUID, account::DemeAccount) = select(instance -> instance.proposal.uuid == uuid, account.instances)


setHome() = reset!(USER_DEMES, DemeItem[item(i) for i in CLIENT.accounts])


function group_slice(collection, n::Int) 

    K = length(collection)

    @assert mod(K, n) == 0

    #s = Vector{T}[]
    s = []

    for i in 1:div(K, n)

        head = 1 + n * (i - 1)
        tail = n * i

        push!(s, collection[head:tail])
    end

    return s
end


function digest_pretty_string(digest::Model.Digest)

    bytes = Model.bytes(digest)[1:16] # Only first 16 are displayed

    str = uppercase(bytes2hex(bytes))
    
    str_pretty = join(group_slice(str, 8), "-")

    return str_pretty
end


function setDeme(uuid::QString)
    

    (; commit, proposals, deme, guard) = select(uuid, CLIENT)

    reset!(DEME_PROPOSALS, ProposalItem[item(instance) for instance in proposals])
    
    DEME_STATUS["uuid"] = QString(uppercase(string(deme.uuid)))
    DEME_STATUS["title"] = deme.title

    #@infiltrate

    DEME_STATUS["memberCount"] = commit.state.member_count

    DEME_STATUS["memberIndex"] = guard.ack.proof.index
    DEME_STATUS["commitIndex"] = commit.state.index

    DEME_STATUS["demeSpec"] = Model.digest(deme, Model.hasher(deme)) |> digest_pretty_string
    
    return
end

setDeme(uuid::UUID) = setDeme(QString(string(uuid)))



function setProposal(index::Int32)

    account = select(DEME_STATUS["uuid"], CLIENT)
    instance = select(index, account)

    PROPOSAL_METADATA["index"] = instance.index
    PROPOSAL_METADATA["title"] = instance.proposal.summary |> copy
    PROPOSAL_METADATA["voterCount"] = instance.proposal.anchor.member_count
    PROPOSAL_METADATA["description"] = instance.proposal.description |> copy
    PROPOSAL_METADATA["stateAnchor"] = instance.proposal.anchor.index

    member_index = account.guard.ack.proof.index

    PROPOSAL_STATUS["isVotable"] = Client.isopen(instance) && member_index < instance.index
    PROPOSAL_STATUS["isCast"] = !isnothing(instance.guard)
    PROPOSAL_STATUS["isTallied"] = Client.istallied(instance)

    PROPOSAL_STATUS["timeWindowShort"] = time_window(instance.proposal)


    tail_str = Client.isopen(instance) && member_index < instance.index ? " to cast your vote" : ""
    PROPOSAL_STATUS["timeWindowLong"] = time_window(instance.proposal) * tail_str

    # make a recent commit method for the instance
    PROPOSAL_STATUS["castCount"] = isnothing(Model.commit(instance)) ? 0 : Model.commit(instance).state.index

    question = "" # Having it empty seems like a possibility
    options = instance.proposal.ballot.options |> copy
    
    pushfirst!(options, "Not Selected")
    choice = 0 

    ballot_question = BallotQuestion(question, options, choice)
    
    reset!(PROPOSAL_BALLOT, BallotQuestion[ballot_question])

    # I the vote is already cast
    !isnothing(instance.guard) && setGuard()

    return
end

setProposal(index::Integer) = setProposal(Int32(index))

function setGuard()

    account = select(DEME_STATUS["uuid"], CLIENT)
    instance = select(PROPOSAL_METADATA["index"], account)

    GUARD_STATUS["pseudonym"] = Model.digest(Model.pseudonym(instance.guard.vote), Model.hasher(account.deme)) |> digest_pretty_string
    GUARD_STATUS["timestamp"] = string(instance.guard.ack_cast.receipt.timestamp)
    GUARD_STATUS["castIndex"] = instance.guard.ack_cast.ack.proof.index

    _commit = Model.commit(instance.guard)

    GUARD_STATUS["commitIndex"] = _commit.state.index
    GUARD_STATUS["commitRoot"] = _commit.state.root |> digest_pretty_string

    return
end




function castBallot()

    items = QML.get_julia_data(PROPOSAL_BALLOT).values[]
    choices = [i.choice for i in items]

    uuid = UUID(DEME_STATUS["uuid"])
    index = PROPOSAL_METADATA["index"]

    Client.cast_vote!(CLIENT, uuid, index, Selection(choices[1]))

    setProposal(index)
    setDeme(uuid)

    return
end


function refreshHome()

    PROPOSAL_METADATA["index"] = 0
    setHome()    

    return
end


function refreshDeme()

    Client.update_deme!(CLIENT, UUID(string(DEME_STATUS["uuid"])))
    setDeme(DEME_STATUS["uuid"])

    return
end


function refreshProposal()

    uuid = UUID(DEME_STATUS["uuid"])
    index = PROPOSAL_METADATA["index"]

    account = select(DEME_STATUS["uuid"], CLIENT)
    instance = select(PROPOSAL_METADATA["index"], account)
    
    if !isnothing(instance.guard)

        Client.check_vote!(account, index)

    else

        Client.get_ballotbox_commit!(account, index)

    end

    setProposal(index)

    return
end


function resetBallot()

    index = PROPOSAL_METADATA["index"]
    setProposal(index)

    return
end


function addDeme(invite::Client.Invite)

    account = Client.enroll!(CLIENT, invite)

    Client.update_deme!(account)
    
    setHome()
    
    return
end


function addDeme(invite_str::QString)

    invite = Parser.unmarshal(invite_str |> String, Client.Invite)
    
    return addDeme(invite)
end


@qmlfunction setDeme setProposal castBallot refreshHome refreshDeme refreshProposal resetBallot addDeme


end
