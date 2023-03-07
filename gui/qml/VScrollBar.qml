import QtQuick 

Rectangle { 

    id : scrollbar

    property int contentY
    property int contentHeight
    property bool active : false
    property bool fitsin : parent.height < contentHeight

    color: "#C6C5C4"
    width : 6
    radius: 0.5 * width 
    
    anchors {
        right : parent.right;  
        margins : radius
    }

    height :  parent.height / contentHeight * parent.height
    y :       contentY / contentHeight * parent.height

    Timer {
         id : timer
         interval : 650
         running : false 
         repeat : false
         onTriggered: scrollbar.active = false
    }

    onYChanged : {
        active = true
        timer.restart()
    }


    states: [
        State { 
            name : "Visible"
            when : scrollbar.active && scrollbar.fitsin
            PropertyChanges {   target: scrollbar; opacity: 1.0 }
        },
        State { 
            name : "InVisible"
            when: !(scrollbar.active && scrollbar.fitsin)
            PropertyChanges {   target: scrollbar; opacity: 0.0 }
        }
    ]


    transitions: Transition {
        from : "Visible"
        to : "InVisible"
        NumberAnimation { property: "opacity"; duration: 150} 
    } 

}

