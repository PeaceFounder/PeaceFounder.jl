import QtQuick 2.15
import QtQuick.Controls 2.15
//import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

import "."

Rectangle {

    id : card

    //anchors.top : parent.top
    anchors.horizontalCenter : parent.horizontalCenter

    height : 250
    width : parent.width * 0.8

    color : Style.statusCardBackground //Style.cardPrimaryBackground //"#1C1C1C" 
    radius : 5

    //property color textColor : "#D9A3A3" //Style.textPrimary
    property color textColor : Style.textPrimary
    

    Column {

        id : details
        anchors.top : parent.top
        anchors.left : parent.left
        anchors.right : parent.right

        anchors.topMargin : 5
        anchors.leftMargin : 5

        spacing : 14

        Item {

            id : ballotbox

            height : 60
            width : parent.width


            Text {
                
                id : title1
                
                anchors.top : parent.top
                anchors.horizontalCenter : parent.horizontalCenter

                color : card.textColor //"#D9A3A3"
                text : "Ballot Box"
                
                font.pointSize: 14


            }


            GridLayout {
                
                anchors.topMargin : 7
                //anchors.leftMargin : 7

                columns: 2
                
                anchors.top : title1.bottom
                anchors.left : parent.left

                Layout.alignment : Qt.AlignVCenter

                Row {

                    spacing : 6

                    Icon {

                        anchors.verticalCenter : parent.verticalCenter
                        
                        height: 16
                        source: "images/Deme.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }


                    Text { 
                        anchors.verticalCenter : parent.verticalCenter
                        width: 50

                        text : "Deme"
                        //color : "#D9A3A3"
                        color : card.textColor
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }


                Text { 

                    text : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 10
                }

                Row {

                    spacing : 6

                    Icon {
                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/Proposal.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }

                    Text {
                        anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "Proposal"
                        color : card.textColor //"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }

                Text { 


                    text : "43"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 14
                }


                
            }

        }
        


        Item {

            height : 90
            width : parent.width

            Text {
                
                id : title2
                
                anchors.top : parent.top
                anchors.horizontalCenter : parent.horizontalCenter

                color : card.textColor //"#D9A3A3"
                text : "Receipt"
                
                font.pointSize: 14

            }



            GridLayout {
                
                anchors.topMargin : 7
                //anchors.leftMargin : 7

                columns: 2
                
                anchors.top : title2.bottom
                anchors.left : parent.left

                Layout.alignment : Qt.AlignVCenter

                Row {

                    spacing : 6

                    Icon {

                        anchors.verticalCenter : parent.verticalCenter
                        
                        height: 16
                        source: "images/Pseudonym.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }


                    Text { 
                        anchors.verticalCenter : parent.verticalCenter
                        width: 50

                        text : "Pseudonym"
                        color : card.textColor//"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }


                Text { 

                    text : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
                    color : card.textColor//"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 10
                }

                Row {

                    spacing : 6

                    Icon {
                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/Timestamp.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }

                    Text {
                        anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "Timestamp"
                        color : card.textColor //"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }

                Text { 


                    text : "June 15, 2009 1:45 PM"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 14
                }
                


                Row {

                    spacing : 6

                    Icon {
                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/CastRecord.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }

                    Text {
                        anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "CastRecord"
                        color : card.textColor //"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }

                Text { 


                    text : "13"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 14
                }
            }


        }


        Item {

            height : 70
            width : parent.width

            Text {
                
                id : title3
                
                anchors.top : parent.top
                anchors.horizontalCenter : parent.horizontalCenter

                color : card.textColor //"#D9A3A3"
                text : "Commit"
                
                font.pointSize: 14

            }

            GridLayout {
                
                anchors.topMargin : 7
                //anchors.leftMargin : 7

                columns: 2
                
                anchors.top : title3.bottom
                anchors.left : parent.left

                Layout.alignment : Qt.AlignVCenter

                Row {

                    spacing : 6

                    Icon {

                        anchors.verticalCenter : parent.verticalCenter
                        
                        height: 16
                        source: "images/Root.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }


                    Text { 
                        
                        anchors.bottom : parent.bottom
                        //anchors.verticalCenter : parent.verticalCenter
                        width: 50

                        text : "Root"
                        color : card.textColor //"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }


                Text { 

                    text : "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 10
                }

                Row {

                    spacing : 6

                    Icon {
                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/State.png"
                        //fillMode: Image.PreserveAspectFit
                        color : card.textColor
                    }

                    Text {
                        
                        anchors.bottom : parent.bottom

                        //anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "Count"
                        color : card.textColor //"#D9A3A3"
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }

                Text { 

                    text : "23"
                    color : card.textColor //"#D9A3A3"
                    //font.weight : Font.Light
                    font.pointSize: 14
                }
                

            }

        }


    }

    
}
