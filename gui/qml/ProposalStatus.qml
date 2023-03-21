import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle { 

    id : statusBar

    anchors.horizontalCenter : parent.horizontalCenter
    
    height : 110
    width : parent.width * 0.8
    
    radius : 5
    color : Style.statusCardBackground


    property int proposalIndex    
    property int stateAnchor
    property int voterCount
    
    property int castCount 
    property bool isCast 
    property bool isTallied 
    property bool isVotable 
    property string timeWindowLong 

    signal vote
    signal guard
    signal tally
    
    Row { 

        anchors.left : parent.left
        anchors.top : parent.top
        anchors.leftMargin : 5
        anchors.topMargin : 5

        spacing : 2

        Icon {
            anchors.bottom : parent.bottom 

            source : "images/Proposal.png" 
            height : 11 
            color : Style.textSecondary

        } 
        

        Text {
            
            anchors.bottom : parent.bottom

            text : "Record: " + statusBar.proposalIndex
            color : Style.textSecondary 
            font.pointSize : 12
            height : 12

        }

    }


    Row { 

        anchors.right : parent.right
        anchors.top : parent.top
        anchors.rightMargin : 5
        anchors.topMargin : 5

        spacing : 2

        Icon {
            anchors.bottom : parent.bottom 

            source : "images/Anchor.png" 
            height : 11
            color : Style.textSecondary

        } 
        

        Text {
            
            anchors.bottom : parent.bottom

            text : "Anchor: " + statusBar.stateAnchor
            color : Style.textSecondary
            font.pointSize : 12
            height : 12

        }

    }


    Item {

        id : bar

        anchors.centerIn : parent
        height : 48
        width : parent.width * 0.8

        property int radius : 5

        
        Rectangle {
            

            anchors.top : parent.top
            anchors.left : parent.left

            width : parent.width
            height : 35

            color : "#4D5B5F" 

            radius : parent.radius


            Rectangle {

                height : parent.height
                width : parent.width * Math.min(statusBar.castCount/statusBar.voterCount, 1)

                radius : bar.radius

                anchors.left : parent.left
                anchors.top : parent.top
                
                color : "#66797E"

            }

            Text {
                
                anchors.centerIn : parent

                color : "#BFC2C2"
                text : statusBar.timeWindowLong 
                
                font.pointSize : 16
                font.weight : Font.Light

            }


            Icon {

                visible : statusBar.isCast

                anchors.right : parent.right
                anchors.verticalCenter : parent.verticalCenter

                anchors.rightMargin : 7
                source : "images/Done.png"

                height : 20
                color : "#B8C2BF"

            }

        }

        Text {
            
            anchors.bottom : parent.bottom
            anchors.left : parent.left

            color : Style.textSecondary
            font.pointSize : 10
            font.weight : Font.Bold

            text : "" + statusBar.castCount + " votes already cast"
        }


        Text {
            
            anchors.bottom : parent.bottom
            anchors.right : parent.right

            color : Style.textSecondary
            font.pointSize : 10
            font.weight : Font.Bold

            text : statusBar.voterCount + " voters"
        
        }


    }

    
    Rectangle {

        id : vote_button


        anchors.bottom : parent.bottom
        anchors.horizontalCenter : parent.horizontalCenter

        anchors.bottomMargin : -15

        width : 200
        height : 30
        
        color : Style.active
        radius : 5

        property string buttonText
        property string textColor 
        property bool shadow : false

        layer {
            enabled: shadow
            effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 8.0
                samples: 16
                color: "#80000000"
            }
        }

        Text {

            anchors.centerIn : parent
            text : parent.buttonText 
            color : parent.textColor 
            font.pointSize : 14

        }

        MouseArea {
            anchors.fill : parent
            onClicked : statusBar.isVotable && statusBar.vote()
        }

        
        states : [

            State {
                name : "open"
                when : statusBar.isVotable
                PropertyChanges {
                    target : vote_button
                    buttonText : "Vote Now"
                    color : Style.active
                    textColor : Style.textIcon
                    shadow : true
                }
            },

            State {
                name : "closed"
                when : !statusBar.isVotable
                PropertyChanges {
                    target : vote_button
                    buttonText : "Closed"
                    color : "#535859" 
                    textColor : "#F3F3F3" 
                    shadow : false
                }
            }

        ]


    }



    Item { 

        anchors.verticalCenter : parent.verticalCenter
        anchors.left : parent.right

        //anchors.bottomMargin : -5
        anchors.leftMargin : -15

        rotation : 90

        width : 70
        height : 30

        Rectangle {

            id : guard_button

            anchors.fill : parent
            
            radius : 5

            property color textColor 

            Text {

                anchors.centerIn : parent
                text : "Guard"
                color : parent.textColor
                font.pointSize : 14

            }

            MouseArea {
                anchors.fill : parent
                onClicked : statusBar.isCast && statusBar.guard()
            }

            states : [
                State {
                    name : "enabled"
                    when : statusBar.isCast
                    PropertyChanges {
                        target : guard_button
                        color : "#9C4649" 
                        textColor : "white"
                        border.width : 0
                    }
                },

                State {
                    name : "disabled"
                    when : !statusBar.isCast
                    PropertyChanges {
                        target : guard_button
                        color : "transparent"
                        textColor : "#BABCBD" 
                        border.width : 2
                        border.color : "#BABCBD" 
                    }
                }

            ]

        }

    }


    Item { 

        anchors.verticalCenter : parent.verticalCenter
        anchors.right : parent.left

        anchors.rightMargin : -15

        rotation : 90

        width : 70
        height : 30

        Rectangle {

            id : tally_button

            anchors.fill : parent
            
            radius : 5

            property color textColor

            Text {

                anchors.centerIn : parent
                text : "Tally"
                color : parent.textColor
                font.pointSize : 14

            }

            MouseArea {
                anchors.fill : parent
                onClicked : statusBar.isTallied && statusBar.tally()
            }


            states : [
                State {
                    name : "enabled"
                    when : statusBar.isTallied
                    PropertyChanges {
                        target : tally_button
                        color : "#66797E"
                        textColor : "white"
                        border.width : 0
                    }
                },

                State {
                    name : "disabled"
                    when : !statusBar.isTallied
                    PropertyChanges {
                        target : tally_button
                        color : "transparent"
                        textColor : "#BABCBD" 
                        border.width : 2
                        border.color : "#BABCBD"
                    }
                }

            ]
        }

    }


}
