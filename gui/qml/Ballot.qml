import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

AppPage {

    id : ballotPage

    title : "Ballot"
    subtitle : "SubTitle"

    preferencesVisible : false
    refreshVisible : false
    trashVisible : true


    property alias model : qlist.model

    signal cast

    
    ListView {

        id : qlist

        anchors.top : parent.top
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.bottom: parent.bottom
        
        spacing : 21

        width : parent.width
        

        delegate : BallotQuestion {

            width : qlist.width * 0.8
            anchors.horizontalCenter : qlist.contentItem.horizontalCenter

            text : question
            model : options

            onCurrentIndexChanged : choice = currentIndex

            property int localChoice : choice // workaraound as role does not have attached signal
            onLocalChoiceChanged : currentIndex = choice

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
            onClicked : ballotPage.cast()
        }
    }

    
    
}
