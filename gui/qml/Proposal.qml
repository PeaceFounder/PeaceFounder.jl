import QtQuick 6.2
import QtQuick.Controls 6.2
//import QtQuick.Controls.Styles


AppPage {
    
    id : proposal

    title : "Proposal"
    subtitle : "Are you ready for a change?"

    signal vote
    signal guard
    signal tally


    VScrollBar {
        
        contentY : view.contentItem.contentY
        contentHeight : view.contentHeight

    }


    ScrollView {

        id : view

        anchors.fill : parent
        contentWidth : parent.width 

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff


        Column { 

            anchors.horizontalCenter : parent.horizontalCenter

            width : parent.width
            spacing : 30

            ProposalStatus {

                onVote : proposal.vote()
                onGuard : proposal.guard()
                onTally : proposal.tally()
            }


            Text {

                anchors.horizontalCenter : parent.horizontalCenter
                width : parent.width * 0.75
                
                wrapMode : Text.WordWrap

                font.weight : Font.Light
                
                lineHeight : 1.5

                color : Style.textPrimary 

                text : "Voting is one of the most important rights and responsibilities that we have as citizens. It is through our collective voice that we can shape the direction of our community, our state, and our nation. The proposed voting question, \"Are you ready for a change?\", is particularly important because it gives us the opportunity to express our desire for a new direction and a fresh approach to the issues that affect us all.

One of the biggest reasons why we need to vote on this proposal is that it addresses the growing sense of frustration and dissatisfaction that many of us feel with the current state of politics. From the lack of progress on critical issues like healthcare and education, to the constant bickering and gridlock in government, it's clear that the status quo is not working. By voting in favor of this proposal, we can send a clear message that we want a change in the way things are done, and that we are willing to support new leaders and new ideas to bring about that change.

Another reason why we need to vote on this proposal is that it gives us the opportunity to take a stand for a more inclusive, equitable, and just society. The current political climate is marked by deep divisions and a growing sense of inequality. By voting for change, we can come together as a community and take action to address the root causes of these problems, such as poverty, discrimination, and systemic injustice. By supporting this proposal, we can send a message that we are committed to building a more fair and equal society for all.

Finally, by voting on this proposal, we can help to ensure that our voices are heard and our interests are represented. In a democratic society, every vote counts, and by casting our ballots, we can help to shape the future of our community and our nation. By taking part in this important vote, we can make a difference and ensure that our voices are heard.

In conclusion, voting on the proposal \"Are you ready for a change?\" is a crucial step in shaping the future of our community and nation. By voting in favor of this proposal, we can express our desire for a new direction, support a more inclusive, equitable, and just society, and ensure that our voices are heard. Let us come together as a community and make our voices count, vote for change."

            }

            Item { 
                height : 150
                width : parent.width 
            }
        }
    }
}
