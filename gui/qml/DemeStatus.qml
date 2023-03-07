import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

import "."

Rectangle {

    //id: rect

    //anchors.top : parent.top
    anchors.horizontalCenter : parent.horizontalCenter

    height : 70
    width : parent.width * 0.8
    //color : Style.cardPrimaryBackground//"#1C1C1C"
    color : Style.statusCardBackground//"#1C1C1C"

    radius: 5


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
                color : Style.textPrimary //"#D9A3A3"
                font.weight : Font.Light
                font.pointSize: 14
            }

        }


        Text { 

            text : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
            color : Style.textPrimary //"#D9A3A3"
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
                //fillMode: Image.PreserveAspectFit
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


            text : "AAF4C61D DCC5E8A2 DABEDE0F 3B482CD9 AEA9434D"
            color : Style.textPrimary //"#D9A3A3"
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
            
            //anchors.bottom : parent.bottom

            Layout.alignment : Qt.AlignLeft
            spacing : 5

            Icon {
                //anchors.verticalCenter : parent.verticalCenter
                height: 18
                source: "images/Member.png"
                //fillMode: Image.PreserveAspectFit
                color : Style.verified
            }

            Text {

                anchors.bottom : parent.bottom

                text : "Member: 57"
                color : Style.verified //"#20741C"
                font.pointSize: 14

            }

        }

        Row {

            //anchors.bottom : parent.bottom

            Layout.alignment : Qt.AlignCenter
            spacing : 5

            Icon {
                //anchors.verticalCenter : parent.verticalCenter
                height: 16
                source: "images/State.png"
                //fillMode: Image.PreserveAspectFit
                color : Style.textPrimary
            }


            Text {

                anchors.bottom : parent.bottom

                text : "State: 260"
                //color : "#D9A3A3"
                font.pointSize: 14

                color : Style.textPrimary
            }


        }


        Row { 

            //anchors.bottom : parent.bottom

            Layout.alignment : Qt.AlignRight
            
            spacing : 5

            Icon {
                //anchors.verticalCenter : parent.verticalCenter
                height: 14
                source: "images/GroupSize.png"
                //fillMode: Image.PreserveAspectFit
                color : Style.textPrimary
            }

            Text {
                
                anchors.bottom : parent.bottom

                text : "GroupSize: 57"
                color : Style.textPrimary //"#D9A3A3"
                font.pointSize: 14

            }

        }
    }

}
