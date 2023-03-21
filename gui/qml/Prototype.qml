import QtQml.Models

App {

    userDemes : ListModel {

        ListElement { commitIndex: 11; title: "Workplace"; uuid: "1AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; memberCount: 15}
        ListElement { commitIndex: 19; title: "Sustainability association"; uuid: "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; memberCount: 120}
        ListElement { commitIndex: 112; title: "Local city concil"; uuid: "3AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; memberCount: 100}
        ListElement { commitIndex: 1145; title: "Local school"; uuid: "4AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; memberCount: 300}

    }

    onSetDeme : uuid => {

        for (let i = 0; i < userDemes.count; i++) {

            if (userDemes.get(i).uuid == uuid) {

                demeStatus.uuid = uuid
                demeStatus.title = userDemes.get(i).title;
                demeStatus.commitIndex = userDemes.get(i).commitIndex;
                demeStatus.memberCount = userDemes.get(i).memberCount;

            }
        }

    }

    demeStatus {

        uuid : "1AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
        title : "Local democratic community" 
        demeSpec : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
        memberIndex : 21
        commitIndex : 89
        memberCount : 16
        
    }

    demeProposals : ListModel { 
        
        ListElement { isVotable : true; isTallied : false; isCast : true; index : 47; voterCount : 243; castCount : 80; title : "Are you ready for a chnage or other kinds of things?"; timeWindow : "23 hours remaining" }
        ListElement { isVotable : false; isTallied : true; isCast : false; index : 67; voterCount : 243; castCount : 80; title : "Are you ready for a chnage or other kinds of things?"; timeWindow : "23 hours remaining" }
        ListElement { isVotable : true; isTallied : false; isCast : false; index : 53; voterCount : 249; castCount : 20; title : "Vote for your representative"; timeWindow : "93 hours remaining" }
        
    } 


    onSetProposal : index => {

        for (let i = 0; i < demeProposals.count; i++) {

            if (demeProposals.get(i).index == index) {

                proposalMetadata.index = index
                proposalMetadata.title = demeProposals.get(i).title
                proposalMetadata.voterCount = demeProposals.get(i).voterCount

                proposalStatus.isVotable = demeProposals.get(i).isVotable
                proposalStatus.isTallied = demeProposals.get(i).isTallied
                proposalStatus.isCast = demeProposals.get(i).isCast
                proposalStatus.timeWindowShort = demeProposals.get(i).timeWindow
                proposalStatus.timeWindowLong = demeProposals.get(i).timeWindow + " to cast your vote"

            }

        }

    }

    proposalMetadata {

        index : 0
        title : "Are you ready for a change"
        description : "Voting is one of the most important rights and responsibilities that we have as citizens. It is through our collective voice that we can shape the direction of our community, our state, and our nation. The proposed voting question, \"Are you ready for a change?\", is particularly important because it gives us the opportunity to express our desire for a new direction and a fresh approach to the issues that affect us all.

One of the biggest reasons why we need to vote on this proposal is that it addresses the growing sense of frustration and dissatisfaction that many of us feel with the current state of politics. From the lack of progress on critical issues like healthcare and education, to the constant bickering and gridlock in government, it's clear that the status quo is not working. By voting in favor of this proposal, we can send a clear message that we want a change in the way things are done, and that we are willing to support new leaders and new ideas to bring about that change.

Another reason why we need to vote on this proposal is that it gives us the opportunity to take a stand for a more inclusive, equitable, and just society. The current political climate is marked by deep divisions and a growing sense of inequality. By voting for change, we can come together as a community and take action to address the root causes of these problems, such as poverty, discrimination, and systemic injustice. By supporting this proposal, we can send a message that we are committed to building a more fair and equal society for all.

Finally, by voting on this proposal, we can help to ensure that our voices are heard and our interests are represented. In a democratic society, every vote counts, and by casting our ballots, we can help to shape the future of our community and our nation. By taking part in this important vote, we can make a difference and ensure that our voices are heard.

In conclusion, voting on the proposal \"Are you ready for a change?\" is a crucial step in shaping the future of our community and nation. By voting in favor of this proposal, we can express our desire for a new direction, support a more inclusive, equitable, and just society, and ensure that our voices are heard. Let us come together as a community and make our voices count, vote for change."
        stateAnchor : 67
        voterCount : 56 

    }

    onRefreshHome : proposalMetadata.index = 0 // One may think of a more complex task here


    proposalStatus {

        isVotable : true
        isCast : false 
        isTallied : false 
        timeWindowShort : "23 hours remaining"
        timeWindowLong : "23 hours remaining to cast your choice" 
        castCount : 23 

    }


    

    guardStatus {

        pseudonym : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
        timestamp : "June 15, 2009 1:45 PM"
        castIndex : 13

        commitIndex : 23 // dublication with castCount
        commitRoot : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"

    }
    


    proposalBallot : ListModel {

        ListElement {
            question : "Which change you would be willing to see?"
            options : [
                ListElement { item : "Not Selected" },
                ListElement { item : "Banana" },
                ListElement { item : "Apple" },
                ListElement { item : "Coconut" }
            ]
            choice : 0
        }

        ListElement {
            question : "When should the change be implemented?"
            options : [
                ListElement { item : "Not Selected" },
                ListElement { item : "Banana" },
                ListElement { item : "Apple" },
                ListElement { item : "Coconut" }
            ]
            choice : 0
        }

        ListElement {
            question : "What budget would you be willing to allocatte for the change?"
            options : [
                ListElement { item : "Not Selected" },
                ListElement { item : "Banana" },
                ListElement { item : "Apple" },
                ListElement { item : "Coconut" }
            ]
            choice : 0
        }

        ListElement {
            question : "Who will be responsable for the change?"
            options : [
                ListElement { item : "Not Selected" },
                ListElement { item : "Banana" },
                ListElement { item : "Apple" },
                ListElement { item : "Coconut" }
            ]
            choice : 0
        }
    }


    onCastBallot : {

        let selections = ""
        
        for (let i = 0; i < proposalBallot.count; i++) {
            selections += proposalBallot.get(i).choice + " "
        }

        proposalStatus.isCast = true

        console.log(selections)

        return true
    }

    onResetBallot : {

        for (let i = 0; i < proposalBallot.count; i++) {
               proposalBallot.setProperty(i, "choice", 0)        
        }

    }

    

}
