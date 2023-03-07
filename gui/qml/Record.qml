import QtQml 


QtObject { 

    component Deme : QtObject { 
    
        property string title
        property var proposals

    }

    component Status : QtObject {

        property bool isVotable
        property bool isCast 
        property bool isTallied
        property string timeWindowShort
        property string timeWindowLong
        property int castCount

    }

    component Question : QtObject {
        property string question
        property list<string> options
    }

    component Proposal : QtObject {

        property string title
        property string descryption
        property string anchor
        property string record
        property int voterCount

        property Status status
        property list<Question> ballot

        property var tally
        property var guard
    }
    

}
