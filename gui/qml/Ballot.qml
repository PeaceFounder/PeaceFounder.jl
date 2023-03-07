import QtQuick 6.2
import QtQuick.Controls 6.2
import Qt5Compat.GraphicalEffects

AppPage {

    id : ballotPage

    title : "Ballot"
    subtitle : "Are you ready for a change?"

    preferencesVisible : false
    refreshVisible : false
    trashVisible : true

    property var ballot 

    signal cast //(list<int> selections)

    // var could be used in more general situation
    property list<int> choices  
    
    onBallotChanged: {
        choices = Array(ballot.length).fill(0) 
    }


    function reset_ballot() {
        
        var temp_ballot = ballotPage.ballot
        ballotPage.ballot = [] 
        ballotPage.ballot = temp_ballot
        qlist.forceLayout()

    }

    

    ListView {

        id : qlist

        anchors.top : parent.top
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.bottom: parent.bottom
        
        spacing : 21

        width : parent.width
        
        model : ballotPage.ballot

        delegate : BallotQuestion {

            property int entryIndex: index


            width : parent.width * 0.8
            anchors.horizontalCenter : parent.horizontalCenter
            question : modelData.question // model.question when ListModel is used
            options : modelData.options

            onIndexChanged : {
                ballotPage.choices[entryIndex] = currentIndex
            }
        }

        
        footer :  Item {
            height : 175
        }

        VScrollBar {

            contentY : parent.contentY
            contentHeight : parent.contentHeight
            
        }


    }

    Rectangle {
        
        anchors.bottom : parent.bottom
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.bottomMargin : 125

        layer {
            enabled: true
            effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 8.0
                samples: 16
                color: "#80000000"
            }
        }

        radius : 5

        width : 200
        height : 30

        color : "#9C4649" 

        Text {

            anchors.centerIn : parent

            font.pointSize : 16
            color : "white"

            text : "Cast your vote"

        }

        MouseArea {
            anchors.fill : parent
            onClicked: ballotPage.cast()
        }
    }

    
    
}
