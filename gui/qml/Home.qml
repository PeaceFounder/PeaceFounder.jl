import QtQuick 2.15
import QtQuick.Controls 2.15
//import QtQuick.Studio.Components 1.0
import Qt5Compat.GraphicalEffects

import "."

AppPage {
    
    anchors.fill : parent
    title : "Home"
    backVisible : false
    
    property ListModel demes

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
                    model: demes

                    footer: Item{

                        width: parent.width * 0.8
                        anchors.horizontalCenter : parent.horizontalCenter

                        height : 200

                        Rectangle { 
                            
                            anchors.top: parent.top
                            anchors.topMargin: 10

                            width: parent.width
                            height: 80
                            
                            color: Style.cardPrimaryBackground
                            
                            radius: 5

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


                            Icon {

                                anchors.centerIn : parent
                                
                                source : "images/Plus.png"
                                height : 48

                                color : "#BBC3C5"
                            }
                            
                        }
                    
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
                    

                    color: Style.cardPrimaryBackground //"#1C1C1C"
                    
                    radius: 5

                    
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        font.pointSize: 18
                        text: model.title
                        color : Style.textPrimary
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        font.pointSize: 9 
                        text: model.uuid
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
                            text: "" + model.groupsize
                        }

                        Icon {
                            anchors.bottom : parent.bottom
                            source : "images/GroupSize.png"
                            height : 10
                            color : Style.textSecondary
                        }


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
