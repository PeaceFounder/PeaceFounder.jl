import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts


Rectangle {

    id : card

    anchors.horizontalCenter : parent.horizontalCenter

    height : 70
    width : parent.width * 0.8
    color : Style.statusCardBackground

    radius: 5


    property string demeUUID
    property string demeSpec
    property int memberIndex
    property int commitIndex
    property int memberCount


    GridLayout {
        
        anchors.topMargin : 3
        anchors.leftMargin : 7

        columns: 2
        
        anchors.top : parent.top
        anchors.left : parent.left

        Layout.alignment : Qt.AlignVCenter

        Row {

            spacing : 6

            Icon {

                anchors.verticalCenter : parent.verticalCenter
                
                height: 14
                source: "images/Deme.png"
                //fillMode: Image.PreserveAspectFit
                color : Style.textPrimary
            }


            Text { 
                anchors.verticalCenter : parent.verticalCenter
                width: 50

                text : "Deme"
                color : Style.textPrimary
                font.weight : Font.Light
                font.pointSize: 14
            }

        }


        Text { 

            text : card.demeUUID
            color : Style.textPrimary 
            font.weight : Font.Light
            font.pointSize: 10
        }

        Row {

            spacing : 6

            Icon {
                anchors.verticalCenter : parent.verticalCenter
                height: 14
                source: "images/Spec.png"
                color : Style.textPrimary
            }

            Text {
                anchors.verticalCenter : parent.verticalCenter
                width : 50

                text : "Spec"
                color : Style.textPrimary //"#D9A3A3"
                font.weight : Font.Light
                font.pointSize: 14
            }

        }

        Text { 
            text : card.demeSpec
            color : Style.textPrimary 
            font.weight : Font.Light
            font.pointSize: 10
        }
        
    }


    RowLayout {
        
        anchors.bottom : parent.bottom
        anchors.left : parent.left
        anchors.right : parent.right

        anchors.bottomMargin : 5
        anchors.leftMargin : 5
        anchors.rightMargin : 5

        Row {
            
            Layout.alignment : Qt.AlignLeft
            spacing : 5

            Icon {

                height: 18
                source: "images/Member.png"
                color : Style.verified

            }

            Text {

                anchors.bottom : parent.bottom

                text : "Member: " + card.memberIndex
                color : Style.verified //"#20741C"
                font.pointSize: 14

            }

        }

        Row {

            Layout.alignment : Qt.AlignCenter
            spacing : 5

            Icon {

                height: 16
                source: "images/State.png"
                color : Style.textPrimary

            }


            Text {

                anchors.bottom : parent.bottom

                text : "State: " + card.commitIndex
                font.pointSize: 14

                color : Style.textPrimary
            }


        }


        Row { 

            Layout.alignment : Qt.AlignRight
            
            spacing : 5

            Icon {

                height: 14
                source: "images/GroupSize.png"
                color : Style.textPrimary

            }

            Text {
                
                anchors.bottom : parent.bottom

                text : "GroupSize: " + card.memberCount
                color : Style.textPrimary //"#D9A3A3"
                font.pointSize: 14

            }

        }
    }

}
