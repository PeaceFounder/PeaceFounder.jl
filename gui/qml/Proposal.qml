import QtQuick
import QtQuick.Controls

AppPage {
    
    id : proposal

    title : "Proposal"


    signal vote
    signal guard
    signal tally

    property string description
    property alias proposalIndex : status.proposalIndex
    property alias stateAnchor : status.stateAnchor
    property alias voterCount : status.voterCount

    property alias castCount : status.castCount
    property alias isCast : status.isCast
    property alias isTallied : status.isTallied
    property alias isVotable : status.isVotable
    property alias timeWindowLong : status.timeWindowLong
    

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

                id : status

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

                text : proposal.description

            }

            Item { 
                height : 150
                width : parent.width 
            }
        }
    }
}
