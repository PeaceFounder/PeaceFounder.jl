ENV["QT_QUICK_CONTROLS_STYLE"] = "Basic"
using QML

include("src/GUI.jl")

import .GUI: DemeItem, ProposalItem, BallotQuestion, reset!, select
import .GUI: USER_DEMES, DEME_STATUS, DEME_PROPOSALS, PROPOSAL_METADATA, PROPOSAL_STATUS, PROPOSAL_BALLOT, GUARD_STATUS


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


function setDeme(uuid::QString) 

    deme = deepcopy(select(item -> item.uuid == uuid, USER_DEMES)) # copying just in case
    
    DEME_STATUS["uuid"] = deme.uuid
    DEME_STATUS["title"] = deme.title
    DEME_STATUS["memberCount"] = deme.memberCount

    reset!(GUI.DEME_PROPOSALS, deme_data[deme.uuid])
    
    return
end


function setProposal(index::Int32) 

    proposal = deepcopy(select(item -> item.index == index, DEME_PROPOSALS))

    PROPOSAL_METADATA["index"] = proposal.index
    PROPOSAL_METADATA["title"] = proposal.title
    PROPOSAL_METADATA["voterCount"] = proposal.voterCount
    PROPOSAL_METADATA["description"] = "Voting is one of the most important rights and responsibilities that we have as citizens. It is through our collective voice that we can shape the direction of our community, our state, and our nation. The proposed voting question, \"Are you ready for a change?\", is particularly important because it gives us the opportunity to express our desire for a new direction and a fresh approach to the issues that affect us all.

One of the biggest reasons why we need to vote on this proposal is that it addresses the growing sense of frustration and dissatisfaction that many of us feel with the current state of politics. From the lack of progress on critical issues like healthcare and education, to the constant bickering and gridlock in government, it's clear that the status quo is not working. By voting in favor of this proposal, we can send a clear message that we want a change in the way things are done, and that we are willing to support new leaders and new ideas to bring about that change.

Another reason why we need to vote on this proposal is that it gives us the opportunity to take a stand for a more inclusive, equitable, and just society. The current political climate is marked by deep divisions and a growing sense of inequality. By voting for change, we can come together as a community and take action to address the root causes of these problems, such as poverty, discrimination, and systemic injustice. By supporting this proposal, we can send a message that we are committed to building a more fair and equal society for all.

Finally, by voting on this proposal, we can help to ensure that our voices are heard and our interests are represented. In a democratic society, every vote counts, and by casting our ballots, we can help to shape the future of our community and our nation. By taking part in this important vote, we can make a difference and ensure that our voices are heard.

In conclusion, voting on the proposal \"Are you ready for a change?\" is a crucial step in shaping the future of our community and nation. By voting in favor of this proposal, we can express our desire for a new direction, support a more inclusive, equitable, and just society, and ensure that our voices are heard. Let us come together as a community and make our voices count, vote for change."

    PROPOSAL_STATUS["isVotable"] = proposal.isVotable
    PROPOSAL_STATUS["isCast"] = proposal.isCast
    PROPOSAL_STATUS["isTallied"] = proposal.isTallied
    PROPOSAL_STATUS["timeWindowShort"] = proposal.timeWindow
    PROPOSAL_STATUS["timeWindowLong"] = proposal.timeWindow * " to cast your vote"
    PROPOSAL_STATUS["castCount"] = proposal.castCount

    return
end


function refreshHome()

    PROPOSAL_METADATA["index"] = 0

    return
end


reset!(PROPOSAL_BALLOT, [
    BallotQuestion("Which change you would be willing to see?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("When should the change be implemented?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("What budget would you be willing to allocatte for the change?", ["Not Selected", "Banana", "Apple", "Coconut"], 0),
    BallotQuestion("Who will be responsable for the change?", ["Not Selected", "Banana", "Apple", "Coconut"], 0)
])


function castBallot()

    items = QML.get_julia_data(PROPOSAL_BALLOT).values[]

    choices = [i.choice for i in items]
    println("Voter have choosen : $choices")

    PROPOSAL_STATUS["isCast"] = true
    
    proposal = select(item -> item.index == PROPOSAL_METADATA["index"], DEME_PROPOSALS)
    proposal.isCast = true 
    
    QML.force_model_update(DEME_PROPOSALS)

    return
end


@qmlfunction setDeme setProposal castBallot refreshHome

GUI.load_view() do

    reset!(USER_DEMES, [
        DemeItem("1AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Workplace", 15),
        DemeItem("2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Local city concil", 120),
        DemeItem("3AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Sustainability association", 100),
        DemeItem("4AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED", "Local school", 300)
    ])

end
