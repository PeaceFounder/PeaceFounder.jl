import QtQuick 2.11
import QtQuick.Shapes 1.15

Shape {
    
    id : shape

    property int radius
    
    width : 2 * radius 
    height: 2 * radius 
    
    property alias startAngle : arc.startAngle
    property alias sweepAngle : arc.sweepAngle
    property alias strokeWidth : path.strokeWidth
    property alias strokeColor : path.strokeColor
    property alias fillColor : path.fillColor

    property bool roundCap : false

    // multisample, decide based on your scene settings
    layer.enabled: true
    layer.samples: 4

    ShapePath {
        
        id : path

        capStyle : if (shape.roundCap) {ShapePath.RoundCap} else {ShapePath.FlatCap}

        PathAngleArc {
            id : arc

            centerX : shape.width/2
            centerY : shape.height/2
            
            radiusX: shape.radius - shape.strokeWidth/2
            radiusY: shape.radius - shape.strokeWidth/2
        }
    }
}
