ENV["QT_QUICK_CONTROLS_STYLE"] = "Basic"

using QML

using Qt65Compat_jll
QML.loadqmljll(Qt65Compat_jll)


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


userDemes = JuliaItemModel([
    DemeItem("1AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Workplace", 15),
    DemeItem("2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Local city concil", 120),
    DemeItem("3AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Sustainability association", 100),
    DemeItem("4AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Local school", 300)
])


#demeUUID = Observable("UNDEFINED")


deme_data = Dict(

    "1AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED" => [

        ProposalItem(47, "Are you ready for a chnage or other kinds of things?", 243, 150, true, false, false, "23 hours remaining"),
        ProposalItem(53, "Should organization be in favour of X policy?", 300, 200, false, false, false, "93 hours remaining")
        
    ],

    "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED" => [

        ProposalItem(67, "Vote for your representative", 200, 20, false, true, false, "15 hours remaining"),
        ProposalItem(53, "Should organization be in favour of X policy?", 300, 200, false, false, false, "93 hours remaining")

    ],

    "3AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED" => [

        ProposalItem(47, "Are you ready for a chnage or other kinds of things?", 243, 150, true, false, false, "23 hours remaining"),
        ProposalItem(67, "Vote for your representative", 200, 20, false, true, false, "15 hours remaining"),

    ],

    "4AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED" => [

        ProposalItem(47, "Are you ready for a chnage or other kinds of things?", 243, 150, true, false, false, "23 hours remaining"),
        ProposalItem(67, "Vote for your representative", 200, 20, false, true, false, "15 hours remaining"),
        ProposalItem(53, "Should organization be in favour of X policy?", 300, 200, false, false, false, "93 hours remaining")

    ]
    
)


#    ProposalItem(47, "Are you ready for a chnage or other kinds of things?", 243, 150, true, false, false, "23 hours remaining"),
#    ProposalItem(67, "Vote for your representative", 200, 20, false, true, false, "15 hours remaining"),
#    ProposalItem(53, "Should organization be in favour of X policy?", 300, 200, false, false, false, "93 hours remaining")


demeProposals = JuliaItemModel(ProposalItem[])


demeStatus = JuliaPropertyMap(
    "uuid" => "UNDEFINED",
    "title" => "Local democratic community",
    "demeSpec" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED",
    "memberIndex" => 21,
    "commitIndex" => 89,
    "memberCount" => 16
)



function setDeme(uuid::QString) 

    #demeStatus["uuid"] = deepcopy(uuid) # copying just in case
    deme = deepcopy(select(item -> item.uuid == uuid, userDemes))
    
    demeStatus["uuid"] = deme.uuid
    demeStatus["title"] = deme.title
    demeStatus["memberCount"] = deme.memberCount

    reset!(demeProposals, deme_data[deme.uuid])
    
    return
end








proposalMetadata = JuliaPropertyMap(
    "index" => 0,
    "title" => "Are you ready for a change",
    "description" => "Voting is one of the most important rights and responsibilities that we have as citizens. It is through our collective voice that we can shape the direction of our community, our state, and our nation. The proposed voting question, \"Are you ready for a change?\", is particularly important because it gives us the opportunity to express our desire for a new direction and a fresh approach to the issues that affect us all.

One of the biggest reasons why we need to vote on this proposal is that it addresses the growing sense of frustration and dissatisfaction that many of us feel with the current state of politics. From the lack of progress on critical issues like healthcare and education, to the constant bickering and gridlock in government, it's clear that the status quo is not working. By voting in favor of this proposal, we can send a clear message that we want a change in the way things are done, and that we are willing to support new leaders and new ideas to bring about that change.

Another reason why we need to vote on this proposal is that it gives us the opportunity to take a stand for a more inclusive, equitable, and just society. The current political climate is marked by deep divisions and a growing sense of inequality. By voting for change, we can come together as a community and take action to address the root causes of these problems, such as poverty, discrimination, and systemic injustice. By supporting this proposal, we can send a message that we are committed to building a more fair and equal society for all.

Finally, by voting on this proposal, we can help to ensure that our voices are heard and our interests are represented. In a democratic society, every vote counts, and by casting our ballots, we can help to shape the future of our community and our nation. By taking part in this important vote, we can make a difference and ensure that our voices are heard.

In conclusion, voting on the proposal \"Are you ready for a change?\" is a crucial step in shaping the future of our community and nation. By voting in favor of this proposal, we can express our desire for a new direction, support a more inclusive, equitable, and just society, and ensure that our voices are heard. Let us come together as a community and make our voices count, vote for change.",
    "stateAnchor" => 67,
    "voterCount" => 56
)


proposalStatus = JuliaPropertyMap(
    "isVotable" => true,
    "isCast" => false,
    "isTallied" => false,
    "timeWindowShort" => "23 hours remaining",
    "timeWindowLong" => "23 hours remaining to cast your choice",
    "castCount" => 23
)



function setProposal(index::Int32) # perhaps Int32

    proposal = deepcopy(select(item -> item.index == index, demeProposals))

    proposalMetadata["index"] = proposal.index
    proposalMetadata["title"] = proposal.title
    proposalMetadata["voterCount"] = proposal.voterCount

    proposalStatus["isVotable"] = proposal.isVotable
    proposalStatus["isCast"] = proposal.isCast
    proposalStatus["isTallied"] = proposal.isTallied
    proposalStatus["timeWindowShort"] = proposal.timeWindow
    proposalStatus["timeWindowLong"] = proposal.timeWindow * " to cast your vote"
    proposalStatus["castCount"] = proposal.castCount

    return
end


function refreshHome()

    proposalMetadata["index"] = 0

    return
end


mutable struct BallotQuestion
    question::String
    options::Vector{String}
    choice::Int
end


proposalBallot = JuliaItemModel([
    BallotQuestion("Which change you would be willing to see?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("When should the change be implemented?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("What budget would you be willing to allocatte for the change?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("Who will be responsable for the change?", ["Not Selected", "Banana", "Apple", "Coconut"], 0)
])


guardStatus = JuliaPropertyMap(
    "pseudonym" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED",
    "timestamp" => "June 15, 2009 1:45 PM",
    "castIndex" => 13,

    "commitIndex" => 23,
    "commitRoot" => "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
)


function castBallot()

    items = QML.get_julia_data(proposalBallot).values[]

    choices = [i.choice for i in items]
    println("Voter have choosen : $choices")

    proposalStatus["isCast"] = true
    
    proposal = select(item -> item.index == proposalMetadata["index"], demeProposals)
    proposal.isCast = true # Is this enough?
    
    QML.force_model_update(demeProposals)

    return
end




@qmlfunction setDeme setProposal castBallot refreshHome


loadqml("qml/Bridge.qml"; 
        _USER_DEMES = userDemes,
        _DEME_STATUS = demeStatus,
        _DEME_PROPOSALS = demeProposals,
        _PROPOSAL_METADATA = proposalMetadata,
        _PROPOSAL_STATUS = proposalStatus,
        _PROPOSAL_BALLOT = proposalBallot,
        _GUARD_STATUS = guardStatus
)

#loadqml("qml/Prototype.qml")

exec()
