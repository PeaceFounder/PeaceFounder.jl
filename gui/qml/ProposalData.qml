import QtQml

QtObject {
    
    property string title
    property string descryption
    property int anchor
    property int record // I could make an alias I guess
    property int voterCount

    property Item status : Item {
        property bool isVotble
        property bool isCast
        property bool isTallied
        property string timeWindowShort
        property string timeWindowLong
        property int castCount
    }

    property var ballot
    property var tally
    property var guard
}
