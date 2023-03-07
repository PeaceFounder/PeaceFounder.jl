import QtQuick 2.15
import QtQuick.Controls 2.15

import "."

AppPage {

    id : deme_page

    anchors.fill: parent
    title : "Deme"
    subtitle : "Local democratic community"


    property var proposal_list

    signal proposal(int record)
    signal tally(int record)
    signal vote(int record)


    ListView { 
        
        anchors.top : parent.top
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.bottom : parent.bottom
        
        width : parent.width

        clip : true

        
        header : Item {

            width : parent.width
            height : status.height + 10

            DemeStatus {
                id : status
                anchors.top : parent.top
            }
        }

        footer : Item {

            width : parent.width
            height : 150

        }

        spacing : 10

        model : deme_page.proposal_list
        
        delegate : ProposalCard {

            anchors.horizontalCenter : parent.horizontalCenter

            isVotable : modelData.isVotable
            isTallied : modelData.isTallied
            isCast : modelData.isCast
            record : modelData.record
            voterCount : modelData.voterCount
            castCount : modelData.castCount
            title : modelData.title
            timeWindow : modelData.timeWindow

            onVote : deme_page.vote(modelData.record)
            onTally : deme_page.tally(modelData.record)
            onProposal : deme_page.proposal(modelData.record)

        }

        VScrollBar {

            contentY : parent.contentY
            contentHeight : parent.contentHeight
            
        }


    }


   
}
