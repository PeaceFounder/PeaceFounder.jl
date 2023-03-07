import QtQuick
import QtQuick.Controls

Item {
    
    id : entry


    property string question : "Which fruit shall we select for a change?"
    property var options : ["Not Selected", "Banana", "Apple", "Coconut"]  // var

    property alias currentIndex : control.currentIndex

    //property alias currentIndexChanged: control.currentIndexChanged //console.debug(currentIndex)  


    signal indexChanged



    height : question_text.implicitHeight + control.implicitHeight

    Text { 

        id : question_text

        width : parent.width
        wrapMode : Text.WordWrap
        
        text : entry.question //"Which fruit shall we select for a change?"
        font.pointSize : 14
        font.weight : Font.Medium
        

    }
    

    CustomComboBox {
        id: control

        anchors.top : question_text.bottom
        anchors.topMargin : 1
        

        anchors.left : parent.left
        anchors.right : parent.right

        anchors.leftMargin : 20


        model: entry.options
        currentIndex: 0

        onCurrentIndexChanged: entry.indexChanged()
    }
}

