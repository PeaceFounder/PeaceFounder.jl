import QtQuick
import QtQuick.Controls

Item { 

    //property alias model : control.model
    property alias model : control.model
    property alias text : label.text

    property alias currentIndex : control.currentIndex

    height : label.implicitHeight + control.implicitHeight
    
    Text {
        id : label

        anchors.left : parent.left
        anchors.topMargin : 10
        
        font.pointSize : 14
        font.weight : Font.Medium
    }

    
    CustomComboBox {
        id : control

        //onModelChanged : 

        anchors.top : label.bottom 
        anchors.topMargin : 1 

        anchors.left : parent.left
        anchors.right : parent.right

        anchors.leftMargin : 20

        width: parent.width
    }

}

