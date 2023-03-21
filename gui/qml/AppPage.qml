import QtQuick
import QtQuick.Controls

Item {

    id : page

    anchors.fill : parent

    default property alias cont : contentArea.children

    property string title : "Home"
    property string subtitle : ""

    property bool backVisible : true
    property bool preferencesVisible : true
    property bool refreshVisible : true
    property bool trashVisible : false

    signal refresh
    signal back
    signal preferences
    signal trash

    Item {
        id : contentArea

        anchors.top : topBar.bottom
        anchors.bottom : parent.bottom
        width : parent.width

    }

    Rectangle {

        id : topBar
        
        height : if (page.subtitle == "") { 32 * 3 } else { 32 * 4}
        color : "transparent"
        anchors.top : parent.top
        anchors.left : parent.left
        anchors.right : parent.right


        Text {
            id: home_title
            
            anchors.horizontalCenter: parent.horizontalCenter
            font.pointSize: 32
            anchors.horizontalCenterOffset: 0

            text: page.title
            anchors.top: parent.top
            anchors.topMargin: 32
            color: Style.textPageHeader //"#D9A3A3"
        

            Text {
                visible : !(page.subtitle == "")

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                font.pointSize: 16
                anchors.topMargin: 16
                text: page.subtitle
                color: Style.textPageHeader 
            }

        }
        


        Icon {
            x: 0
            y: 6
            //width: 40
            height: 40
            anchors.left: parent.left
            anchors.top: parent.top
            source: "images/Back.png"
            anchors.leftMargin: 0
            anchors.topMargin: 6
            //fillMode: Image.PreserveAspectFit

            color : Style.toolBar

            visible : page.backVisible

            MouseArea {
                anchors.fill: parent 
                onClicked: back()
            } 
        }

        Row {

            //y : 6
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6
            anchors.topMargin: 6

            Icon {
                visible : page.trashVisible
                
                height: 40
                source: "images/Trash.png"
                color : Style.toolBar

                MouseArea {
                    anchors.fill: parent
                    onClicked: trash()
                }

            }

            Icon {

                visible : page.refreshVisible

                height: 40
                source: "images/Refresh.png"
                color : Style.toolBar

                MouseArea {
                    anchors.fill: parent
                    onClicked: refresh()
                }

            }

            Icon {

                visible : page.preferencesVisible
                
                height: 40
                source: "images/Preferences.png"
                color : Style.toolBar

                MouseArea {
                    anchors.fill: parent
                    onClicked: preferences()
                }

            }


        }
    }
}
