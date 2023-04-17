import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

//import "."

AppPage {
    id : homePage

    anchors.fill : parent
    title : "Home"
    backVisible : false
    
    signal demeCard(string uuid)
    signal addDeme(string invite)

    property alias userDemes : demes_view.model

    Item {

        anchors.fill: parent

        Item {
            id: home_view
            anchors.fill: parent
            anchors.horizontalCenter : parent.horizontalCenter


                ListView {
                    id: demes_view
             
                    anchors.fill : parent

                    spacing: 10
                    
                    delegate: demes_delegate

                    footer: PlusDeme {
                        onAddDeme : invite => homePage.addDeme(invite)
                    }

                    VScrollBar {

                        contentY : parent.contentY
                        contentHeight : parent.contentHeight
                        
                    }

            }
            

            Component { 
                id: demes_delegate 

                Item {

                    width: demes_view.width * 0.8
                    anchors.horizontalCenter : parent.horizontalCenter
                    height: 80


                Rectangle {

                    id : view_rect
                    
                    anchors.fill : parent

                    color: Style.cardPrimaryBackground
                    
                    radius: 5

                    
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        font.pointSize: 18
                        //text: model.title
                        text : title
                        color : Style.textPrimary
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        font.pointSize: 9 
                        //text: model.uuid
                        text : uuid
                        anchors.topMargin: 4
                        anchors.rightMargin: 4
                        color : Style.textTeritary
                    }


                    Row {
                        
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        anchors.rightMargin: 5

                        spacing : 2

                        height : 12

                        Text {
                            font.pointSize: 12
                            color : Style.textSecondary
                            //text: "" + model.groupsize
                            text : memberCount
                        }

                        Icon {
                            anchors.bottom : parent.bottom
                            source : "images/GroupSize.png"
                            height : 10
                            color : Style.textSecondary
                        }


                    }
                    

                    MouseArea {
                        anchors.fill : parent
                        onClicked : demeCard(uuid)
                    }

                }


                DropShadow {
                    anchors.fill: view_rect
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 8.0
                    samples: 16
                    color: "#80000000"
                    source: view_rect
                }

                }

            }


        }
    }
}
