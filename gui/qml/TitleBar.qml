import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Studio.Components 1.0


Item { // rectangle could be an option to change the color when stuff gets scrooled up
    
    property string title : "Home"
    property string subtitle

    Text {
        id: home_title
        
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: 32
        anchors.horizontalCenterOffset: 0

        text: parent.title
        anchors.top: parent.top
        anchors.topMargin: 32
        color: "#D9A3A3"
    }


    Image {
        id: back
        x: 0
        y: 6
        width: 40
        anchors.left: parent.left
        anchors.top: parent.top
        source: "images/Back.png"
        anchors.leftMargin: 0
        anchors.topMargin: 6
        fillMode: Image.PreserveAspectFit

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (menu.page == 5) {
                    menu.page = 3
                } else {
                    menu.page = menu.page - 1
                }
            }

        }
    }

    Image {
        id: preferences
        x: 434
        y: 6
        width: 40
        height: 40
        anchors.right: parent.right
        anchors.top: parent.top
        source: "images/Preferences.png"
        anchors.rightMargin: 6
        anchors.topMargin: 6
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: refresh
        x: 388
        y: 6
        width: 40
        anchors.right: preferences.left
        anchors.top: parent.top
        source: "images/Refresh.png"
        anchors.rightMargin: 6
        anchors.topMargin: 6
        fillMode: Image.PreserveAspectFit


        MouseArea {
            anchors.fill: parent
            onClicked: content.refresh()
        }

    }

}
