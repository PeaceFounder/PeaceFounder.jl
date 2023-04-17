import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects


Item {

    id: plusDeme

    width: parent.width * 0.8
    anchors.horizontalCenter : parent.horizontalCenter

    height : 200

    state : "waiting"

    signal addDeme(string invite)

    Rectangle { 

        id: footer
        
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


        Item { 

            id: plus
            anchors.fill : parent

            Icon {

                anchors.centerIn : parent
                
                source : "images/Plus.png"
                height : 48

                color : "#BBC3C5"
            }

            MouseArea {
                
                anchors.fill : parent
                onClicked: plusDeme.state = "clicked"

            }

        }


        Item {

            id: form
            anchors.fill : parent
            visible : false


            Rectangle { 

                anchors.centerIn : parent

                width : parent.width - 10
                height : parent.height - 10
                color : "#ECEAE6" //"linen"

                radius: 5
                
                border.width : 1
                border.color: "#A3AFB2"
                

                TextEdit {
                    id : input
                    anchors.centerIn : parent
                    width : parent.width - 10
                    height : parent.height - 10

                    wrapMode : TextInput.WrapAnywhere
                    
                    onActiveFocusChanged : {
                        if (activeFocus) {
                            text = ""
                        }
                    }
                }

            }

        }

    }



    Rectangle {

        id : add_deme

        anchors.bottom : footer.bottom
        
        anchors.horizontalCenter : parent.horizontalCenter
        anchors.bottomMargin : -15 * 3

        //anchors.bottom : parent.bottom
        //anchors.bottomMargin : 50

        width : 200
        height : 30
        
        color : Style.active
        radius : 5

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

        Text {

            anchors.centerIn : parent
            color : "white"
            font.pointSize : 14
            text : "Add Deme"

        }

        MouseArea {
            anchors.fill : parent
            onClicked : {
                plusDeme.addDeme(input.text)
                //console.log(input.text)
                plusDeme.state = "waiting"
                input.focus = false
            }
        }
    }

    states : [

        State {
            name : "waiting"
            PropertyChanges {target : plus; visible : true }
            PropertyChanges {target : form; visible : false }
            PropertyChanges {target : add_deme; visible : false }
        },

        State {
            name : "clicked"
            PropertyChanges {target : plus; visible : false }
            PropertyChanges {target : form; visible : true }
            PropertyChanges {target : add_deme; visible : true }
            PropertyChanges {target : input; text : "Paste invite here"}
        }

    ]
    

}
