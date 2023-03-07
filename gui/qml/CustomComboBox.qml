import QtQuick
import QtQuick.Controls

ComboBox {
    id: control

    height : 30

    contentItem: Text {
        
        height : base.height

        anchors.left : base.left
        anchors.right : base.right

        anchors.leftMargin : 13
        anchors.rightMargin : 10 + 30 //+ control.indicator.width

        text: control.displayText
        font: control.font
        color: "black" //control.pressed ? "#17a81a" : "#21be2b"
        verticalAlignment: Text.AlignVCenter
        //elide: Text.ElideRight
    }


    delegate: ItemDelegate {

        width : control.width
        height : base.height

        contentItem: Item {

            height : base.height
            width  : base.width

            Text {
                
                anchors.verticalCenter : parent.verticalCenter
                anchors.left : parent.left
                anchors.right : parent.right
                
                //leftPadding : 3

                text: modelData
                color : "black"

            }

        }

        highlighted: control.highlightedIndex === index

        background: Rectangle {
            
            id : backgr

            width : parent.width
            height : parent.height
            color : if (parent.highlighted) {"#ECEAE6"} else {"#FBF7F4"}
        }

    }


    background: Rectangle {

        id : base

        radius : 5
        
        height : 30

        color: "#ECEAE6" 

        border.color: "#A3AFB2"
        border.width: 1

    }


    indicator : Icon {

        anchors.right : parent.right
        anchors.verticalCenter : base.verticalCenter
        
        anchors.rightMargin : 10
        
        height : 16
        color : "#526165"
        source : "images/DropDown.png"
    }


    popup: Popup {
        y: control.height + 2
        
        width: control.width
        padding: 1

        background: Rectangle {
            color: "transparent"
            border.width : 1
            border.color: "#A3AFB2"
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            
            ScrollIndicator.vertical: ScrollIndicator { }

        }

    }
}
