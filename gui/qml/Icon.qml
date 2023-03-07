import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Item {

    property string source
    height : 12
    property string color : "black"

    //implicitHeight : parent.height
    implicitHeight : height
    implicitWidth : height * icon.sourceSize.width/icon.sourceSize.height

    //implicitWidth : icon.width
    
    Image {
        id : icon

        //smooth : false

        anchors.fill : parent

        height: parent.height
        source: parent.source
        fillMode: Image.PreserveAspectFit
    }


    ColorOverlay {
        anchors.fill: icon
        source: icon
        color: parent.color
    }

}


/* import QtQuick */
/* import QtQuick.Controls */

/* Item { */

/*     implicitHeight: 12 */
/*     implicitWidth: height */

/*     property alias source : btn.icon.source */
/*     property alias color : btn.icon.color */

/*     signal clicked() */
/*     Button { */
/*         id : btn */
/*         anchors.centerIn: parent */
/*         background: Item { } */
/*         icon.width: parent.width */
/*         icon.height: parent.height */

/*         smooth : false */
/*     } */
/* } */

