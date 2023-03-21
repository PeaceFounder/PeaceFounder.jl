import QtQuick
import QtQuick.Controls

Rectangle {

    property int radius: 43
    property int mheight: 5
    property int mwidth: 40
    property int border_width: 3

    property string active_color: Style.active 
    property string inactive_color: Style.inactive 
    property string text_color: Style.textStepperMenu
    property string icon_color: Style.stepperMenuIcon

    property color iconDisabled : "transparent"

    property int page : 1
    property bool trod : false
    property bool votable : false
    property bool observable : false

    signal home
    signal deme
    signal proposal
    signal vote
    signal observe

    Rectangle {
        id: rectangle1
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        layer.smooth: false
        layer.enabled: false
        enabled: true
        width: parent.mwidth
        height: parent.mheight
        color: if (parent.page >= 2) {parent.active_color} else {parent.inactive_color}
        smooth: false
    }

    Rectangle {
        id: rectangle2
        x: 80
        width: parent.mwidth
        height: parent.mheight
        color: if (parent.page >= 3) {parent.active_color} else {parent.inactive_color}
        anchors.verticalCenter: parent.verticalCenter
        smooth: false
    }


    Rectangle {
        id: rectangle3
        x: 160
        width: parent.mwidth
        height: parent.mheight
        color: if (parent.page >= 4) {parent.active_color} else {parent.inactive_color}
        anchors.verticalCenter: parent.verticalCenter
        smooth: false
    }


    Rectangle {
        id: rectangle4
        x: 240
        width: parent.mwidth
        height: parent.mheight
        color: if (parent.page >= 5) {parent.active_color} else {parent.inactive_color}
        anchors.verticalCenter: parent.verticalCenter
        smooth: false
    }


    Rectangle {
        x: -40
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0

        width: parent.radius
        height: parent.radius
        radius : parent.radius

        color: parent.active_color


        Icon {
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            color : Style.stepperMenuIcon
            source: "images/Home.png"
        }

        Text {
            color: parent.parent.text_color
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            font.styleName: "Semibold"
            text: "Home"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.parent.home()
        }
    }

    Rectangle {
        x: 40
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        
        width: parent.radius
        height: parent.radius
        radius : parent.radius

        color : if (parent.page >= 2) {parent.active_color} else {if (parent.trod) {parent.inactive_color} else {parent.iconDisabled}}
        border.color : if (parent.page >= 2) {parent.active_color} else {parent.inactive_color}
        border.width : parent.border_width

        Icon {
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            color :  if (parent.parent.page >= 2) {Style.stepperMenuIcon} else {Style.stepperMenuIconDisabled}
            source: "images/Deme.png"
        }

        Text {
            color: parent.parent.text_color
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            font.styleName: "Semibold"
            text: "Deme"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.parent.deme()
        }
    }

    Rectangle {
        x: 120
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        
        width: parent.radius
        height: parent.radius
        radius : parent.radius
        
        color : if (parent.page >= 3) {parent.active_color} else {if (parent.trod) {parent.inactive_color} else {parent.iconDisabled}}
        border.color : if (parent.page >= 3) {parent.active_color} else {parent.inactive_color}
        border.width : parent.border_width

        Icon {
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/Proposal.png"
            color : if (parent.parent.page >= 3) {Style.stepperMenuIcon} else {Style.stepperMenuIconDisabled}
        }

        Text {
            color: parent.parent.text_color
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            font.styleName: "Semibold"
            text: "Proposal"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.parent.proposal()
        }
    }

    Rectangle {
        x: 200
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0

        width: parent.radius
        height: parent.radius
        radius : parent.radius

        color : if (parent.trod && parent.votable) { if (parent.page >= 4) {parent.active_color} else {parent.inactive_color} } else {parent.iconDisabled}
        border.color : if (parent.page >= 4) {parent.active_color} else {parent.inactive_color}
        border.width : parent.border_width

        Icon {
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/Vote.png"
            color : if (parent.parent.page >= 4 && parent.parent.votable) {Style.stepperMenuIcon} else {Style.stepperMenuIconDisabled}         }

        Text {
            color: parent.parent.text_color
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            font.styleName: "Semibold"
            text: "Ballot"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.parent.vote()
        }
    }

    Rectangle {
        x: 280
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        
        radius : parent.radius
        width: parent.radius
        height: parent.radius
        
        color : if (parent.trod && parent.observable) {if (parent.page >= 5) {parent.active_color} else {parent.inactive_color}} else {parent.iconDisabled}
        border.color : if (parent.page >= 5) {parent.active_color} else {parent.inactive_color}
        border.width : parent.border_width

        Icon {
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
             source: "images/Observe.png"
            color : if (parent.parent.page == 5) {Style.stepperMenuIcon} else {Style.stepperMenuIconDisabled} 
        }

        Text {
            color: parent.parent.text_color
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 33
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            font.styleName: "Semibold"
            text: "Guard"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.parent.observe()
        }
    }
}


