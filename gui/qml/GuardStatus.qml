import QtQuick
import QtQuick.Controls
import QtQuick.Layouts


Rectangle {

    id : card

    anchors.horizontalCenter : parent.horizontalCenter

    height : 250
    width : parent.width * 0.8

    color : Style.statusCardBackground
    radius : 5

    property color textColor : Style.textPrimary

    property string demeUUID
    property int proposalIndex
    
    property string pseudonym
    property string timestamp
    property int castIndex

    property int commitIndex
    property string commitRoot
        

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

                color : card.textColor
                text : "Ballot Box"
                
                font.pointSize: 14


            }


            GridLayout {
                
                anchors.topMargin : 7

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
                        color : card.textColor
                        font.pointSize: 14
                    }

                }


                Text { 

                    text : card.demeUUID
                    color : card.textColor
                    font.pointSize: 10

                }

                Row {

                    spacing : 6

                    Icon {
                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/Proposal.png"
                        color : card.textColor
                    }

                    Text {
                        anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "Proposal"
                        color : card.textColor
                        font.pointSize: 14
                    }

                }

                Text { 

                    text : card.proposalIndex
                    color : card.textColor
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

                color : card.textColor 
                text : "Receipt"
                
                font.pointSize: 14

            }



            GridLayout {
                
                anchors.topMargin : 7

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
                        color : card.textColor
                        //font.weight : Font.Light
                        font.pointSize: 14
                    }

                }


                Text { 

                    text : card.pseudonym
                    color : card.textColor
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


                    text : card.timestamp
                    color : card.textColor //"#D9A3A3"
                    font.pointSize: 14

                }

                Row {

                    spacing : 6

                    Icon {

                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/CastRecord.png"
                        color : card.textColor

                    }

                    Text {

                        anchors.verticalCenter : parent.verticalCenter
                        width : 80

                        text : "CastRecord"
                        color : card.textColor

                        font.pointSize: 14
                    }

                }

                Text { 

                    text : card.castIndex
                    color : card.textColor
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

                color : card.textColor
                text : "Commit"
                
                font.pointSize: 14

            }

            GridLayout {
                
                anchors.topMargin : 7

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
                        color : card.textColor

                    }


                    Text { 
                        
                        anchors.bottom : parent.bottom
                        width: 50

                        text : "Root"
                        color : card.textColor
                        font.pointSize: 14

                    }

                }


                Text { 

                    text : card.commitRoot
                    color : card.textColor
                    font.pointSize: 10

                }

                Row {

                    spacing : 6

                    Icon {

                        anchors.verticalCenter : parent.verticalCenter
                        height: 16
                        source: "images/State.png"
                        color : card.textColor

                    }

                    Text {
                        
                        anchors.bottom : parent.bottom

                        width : 80

                        text : "Count"
                        color : card.textColor
                        font.pointSize: 14
                    }

                }

                Text { 

                    text : card.commitIndex 
                    color : card.textColor
                    font.pointSize: 14

                }

            }

        }


    }
    
}
