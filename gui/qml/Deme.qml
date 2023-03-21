import QtQuick
import QtQuick.Controls

//import "."

AppPage {

    id : page

    anchors.fill: parent
    title : "Deme"
    subtitle : "Subtitle"


    property var demeProposals

    // Does not work for some reason...
    //property alias demeUUID : status.demeUUID
    //property alias demeSpec : status.demeSpec
    //property alias memberIndex : status.memberIndex
    //property alias commitIndex : status.commitIndex
    //property alias groupSize : status.groupSize

    property string demeUUID
    property string demeSpec
    property int memberIndex
    property int commitIndex
    property int memberCount


    signal proposal(int record)
    signal tally(int record)
    signal vote(int record)


    ListView { 

        id : listView
        
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

                demeUUID : page.demeUUID
                demeSpec : page.demeSpec
                memberIndex : page.memberIndex
                commitIndex : page.commitIndex
                memberCount : page.memberCount

                anchors.top : parent.top
            }
        }

        footer : Item {

            width : parent.width
            height : 150

        }

        spacing : 10

        model : page.demeProposals
        
        delegate : ProposalCard {

            anchors.horizontalCenter : listView.contentItem.horizontalCenter //parent.horizontalCenter
            width : 0.8 * listView.width

            isVotable : model.isVotable
            isTallied : model.isTallied
            isCast : model.isCast
            index : model.index
            voterCount : model.voterCount
            castCount : model.castCount
            title : model.title
            timeWindow : model.timeWindow

            onVote : page.vote(model.index)
            onTally : page.tally(model.index)
            onProposal : page.proposal(model.index)

        }

        VScrollBar {

            contentY : parent.contentY
            contentHeight : parent.contentHeight
            
        }


    }


   
}
