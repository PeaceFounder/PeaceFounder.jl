import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

Rectangle {

    id : base

    height : 110
    color : Style.cardCreamBackground

    radius : 5

    property bool isVotable : true
    property bool isTallied : true
    property bool isCast : true
    property int index : 57
    property int voterCount : 243
    property int castCount : 80
    property string title : "Are you ready for a chnage or other kinds of things?"
    property string timeWindow : "23 hours remaining"
    
    signal vote
    signal tally
    signal proposal

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

    MouseArea {
        anchors.fill : parent
        onClicked : base.proposal()
    }


    Item {

        id : clock_rect

        property int radius : 5
        property int side : 110
        property string color : Style.cardPrimaryBackground

        width : side + 5
        height : side
        
        Rectangle {

            width : parent.side
            height : parent.side

            anchors.left : parent.left
            anchors.top : parent.top

            color : parent.color

            radius : 5

        }

        Rectangle {

            width : parent.radius
            height : parent.side

            anchors.left : parent.left
            anchors.top : parent.top

            anchors.leftMargin : parent.side - parent.radius

            color : parent.color

        }

    }


    Arc {
        id: base_arc

        anchors.left : clock_rect.left
        anchors.bottom : clock_rect.bottom

        anchors.bottomMargin : -7
        anchors.leftMargin : 5


        radius : 110/2
        
        roundCap : true

        startAngle : 45
        sweepAngle : -(360 - 2 * startAngle)

        strokeWidth: 10
        strokeColor: Style.progressBarBacground
        fillColor: "transparent" 
    }


    Arc {
        id: cast_arc

        anchors.centerIn : base_arc

        radius : 110/2
        
        roundCap : true

        startAngle : base_arc.startAngle 
        sweepAngle : -(360 - 2 * startAngle) * Math.min(base.castCount/base.voterCount, 1)

        strokeWidth: 10
        strokeColor: Style.progressBar
        fillColor: "transparent" 
    }


    Text {

        width : 70

        anchors.centerIn : base_arc 
        anchors.verticalCenterOffset : -3

        wrapMode : Text.WordWrap
        text : base.timeWindow

        font.pointSize : 14

        horizontalAlignment: Text.AlignHCenter

        color : Style.progressBar

    }


    Row {
        anchors.horizontalCenter : base_arc.horizontalCenter
        anchors.bottom : clock_rect.bottom 
        anchors.bottomMargin : 9

        spacing : 2

        Text {
            anchors.bottom : parent.bottom

            color : Style.textTeritary
            text : "" + base.voterCount
            font.pointSize : 10
            height : 10
        }

        Icon {  
            height : 10
            source : "images/GroupSize.png"  
            color : Style.textTeritary
        }
    }


    Text {


        anchors.left : clock_rect.right
        anchors.right : base.right
        anchors.top : base.top

        anchors.leftMargin : 5
        anchors.rightMargin : 30
        anchors.topMargin : 2

        text : base.title
        color: Style.textPrimary

        wrapMode : Text.WordWrap
        font.pointSize : 18


    }


    Row { 

        anchors.left : clock_rect.right
        anchors.bottom : base.bottom
        anchors.leftMargin : 5
        anchors.bottomMargin : 5

        spacing : 2

        Icon {

            anchors.bottom : parent.bottom 

            source : "images/Proposal.png" 
            height : 11 
            color : Style.textSecondary

        } 
        

        Text {
            
            anchors.bottom : parent.bottom

            text : "Record: " + base.index
            color : Style.textSecondary
            font.pointSize : 12
            height : 12
        }

    }

    Icon {

        anchors.right : base.right
        anchors.top : base.top

        anchors.rightMargin : 5
        anchors.topMargin : 5

        source : "images/Approval.png"

        height : 22
        color : if (base.isCast) {Style.creamVerified} else {"#EEEDEC"}

    }


    Row {

        anchors.right : base.right
        anchors.bottom : base.bottom

        anchors.rightMargin : 5
        anchors.bottomMargin : 5

        spacing : 5

        Rectangle {
            id : vote_button

            width : 80
            height : 30
            radius : 5

            property color textColor
            property bool shadow

            Text {
                
                anchors.centerIn : parent
                text : "Vote Now"
                color : parent.textColor
                font.pointSize : 14

            }

            layer {
                enabled : shadow
                effect : DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 8.0
                    samples: 16
                    color: "#80000000"
                }
            }

            MouseArea {
                anchors.fill : parent
                onClicked : base.isVotable && base.vote() 
            }

            
            states : [
                
                State {
                    name : "enabled"
                    when : base.isVotable
                    PropertyChanges {
                        target : vote_button
                        color : Style.active
                        textColor : Style.textIcon
                        shadow : false
                    }
                },

                State {
                    name : "disabled"
                    when : !base.isVotable
                    PropertyChanges {
                        target : vote_button
                        color : "transparent"
                        textColor: Style.textInactive
                        border.color: Style.textInactive
                        border.width: 1
                        shadow : false
                    }
                }
            ]


        }


        Rectangle {

            id : tally_button


            width : 80
            height : 30
            radius : 5

            property color textColor
            property bool shadow

            Text {

                anchors.centerIn : parent
                text : "Tally"
                color : parent.textColor
                font.pointSize : 14

            }

            layer {
                enabled : shadow
                effect : DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 8.0
                    samples: 16
                    color: "#80000000"
                }
            }

            MouseArea {
                anchors.fill : parent
                onClicked : base.isTallied && base.tally() 
            }

            states: [
                State { 
                    name: "enabled"
                    when: base.isTallied 
                    PropertyChanges { 
                        target: tally_button
                        color : "#66797E"
                        textColor: "white"
                        shadow : false
                    }
                },
                State { 
                    name: "disabled"
                    when: !base.isTallied 
                    PropertyChanges { 
                        target: tally_button
                        color : "transparent"
                        textColor: Style.textInactive
                        border.color: Style.textInactive
                        border.width: 1
                        shadow : false
                    }
                }
            ]

        }


    }

}
