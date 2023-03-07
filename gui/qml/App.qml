import QtQuick 6.2
import QtQuick.Window 6.2
import QtQuick.Controls 6.2

//import QtQuick.Studio.Components 1.0
//import Qt5Compat.GraphicalEffects

import Qt5Compat.GraphicalEffects



Window {
    id: window
    width: 550
    height: 700

    visible: true
    color: Style.pageBackground 
    title: "Navigation"

    property string deme : "AE1342 B57225" 
    property int proposal : 53


    property Record.Deme demeData : Record.Deme {
        title : "A local democratic community"
        proposals : [
            
            { isVotable : true, isTallied : false, isCast : true, record : 47, voterCount : 243, castCount : 80, title : "Are you ready for a chnage or other kinds of things?", timeWindow : "23 hours remaining" },

            { isVotable : true, isTallied : false, isCast : false, record : 53, voterCount : 249, castCount : 20, title : "Vote for your representative", timeWindow : "93 hours remaining" }
            
        ]
    }


    property Record.Proposal proposalData : Record.Proposal {

        title : "Are you ready for a change"
        descryption : "A long description for otivation"
        voterCount : 56 // This is a data which could be stored with in Proposal as it is dependant on the freely chosen anchor
        status : Record.Status {
            isVotable : true
            isCast : false
            isTallied : false
            timeWindowShort : "23 hours remaining"
            timeWindowLong : "23 hours remaining to cast your choice"
            castCount : 23
        }

        //tally 
        //guard
        
        ballot : [
            Record.Question {
                question : "Which change you would be willing to see?"
                options : ["Not Selected", "Banana", "Apple", "Coconut"]
            },
            Record.Question {
                question : "When should the change be implemented?"
                options : ["Not Selected", "Banana", "Apple", "Coconut"]
            },
            Record.Question {
                question : "What budget would you be willing to allocatte for the change?"
                options : ["Not Selected", "Banana", "Apple", "Coconut"]
            },
            Record.Question {
                question : "Who will be responsable for the change?"
                options : ["Not Selected", "Banana", "Apple", "Coconut"]
            }
        ]
    }
    
    
    property int page : 1
    
    // I will need to update this on change of proposalData
    property bool isvotable : true
    property bool iscast : false


    property ListModel deme_list : ListModel {
        
        ListElement { commit: 11; title: "Workplace"; uuid: "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; groupsize: 15} // 00000-3928c-00000-3928c-00000-3928c-00000-3928c
        ListElement { commit: 19; title: "Sustainability association"; uuid: "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; groupsize: 120}
        ListElement { commit: 112; title: "Local city concil"; uuid: "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; groupsize: 100}
        ListElement { commit: 1145; title: "Local school"; uuid: "2AAE6C35 C94FCFB4 15DBE95F 408B9CE9 1EE846ED"; groupsize: 300}
        
    }

    Item {

        id : content
        anchors.fill : parent

        Home {
            id : home
            state : "home"

            demes : window.deme_list

            onRefresh : menu.trod = false
        }


        Deme {
            id : deme
            state : "deme"
            onBack : menu.page = 1

            //proposal_list : window.proposal_list
            proposal_list : window.demeData.proposals
            //proposal_list //: window.proposals


            onProposal : record => {
                console.log("Proposal " + record)
                window.proposal = record
                window.page = 3
            }
            onTally : record => {
                console.log("Tally " + record)
                window.proposal = record
                window.page = 3
                // tally view
            }

            onVote : record => {
                console.log("Vote " + record)
                window.proposal = record
                window.page = 4
            }

        }


        Proposal {
            id : proposal
            state : "proposal"
            onBack : menu.page = 2

            onVote : menu.page = 4
            onGuard : menu.page = 5
                
        }


        Ballot {
            id : vote
            state : "vote"
            onBack : menu.page = 3
            
            ballot : window.proposalData.ballot

            onCast : {
                console.log(choices)
                reset_ballot()
                menu.page = 5
            }

            onTrash : {
                reset_ballot()
                //menu.page = 4
            }
        }

        
        Guard {
            id : observe
            state : "observe"
            onBack : menu.page = 3
        }
        


    }
        


    Rectangle {
        id: rect
        anchors.fill: fastBlur
        color: Style.stepperBackground //"#241b1b"
    }


    DropShadow {
        anchors.fill: rect
        //cached: true
        horizontalOffset: 0
        verticalOffset: 0
        radius: 8.0
        samples: 16
        color: "#80000000"
        source: rect
    }

    FastBlur {
        id: fastBlur
        height: 72
        width: parent.width
        anchors.bottom: parent.bottom
        //height: 72
        radius: 32
        opacity: 0.55
        source: ShaderEffectSource {
            sourceItem: content
            sourceRect: Qt.rect(0, window.height - fastBlur.height, fastBlur.width, fastBlur.height)
        }
    }


    StepperMenu {
        id: menu
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 45

        page : 1
        trod : false
        votable : true
        observable : true

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -140

        onHome: {
            page = 1

            window.page = 3
            window.deme = 0
            window.proposal = 0
            window.isvotable = true
            window.iscast = 0
        }

        onDeme: {
            page = 2
        }

        onProposal: {
            page = 3
            trod = true
        }

        onVote: {
            if (votable) {
                page = 4
            }
        }

        onObserve: {
            if (observable) {
                page = 5
            }
        }
    }



    StateGroup {
        id: stateGroup
        states: [
            State {
                name: "home"
                when: menu.page == 1
                PropertyChanges { target: home; visible:true; }
                PropertyChanges { target: deme; visible:false; }
                PropertyChanges { target: proposal; visible:false; }
                PropertyChanges { target: vote; visible:false; }
                PropertyChanges { target: observe; visible:false; }
                //PropertyChanges { target: back; visible:false; }

                /* PropertyChanges {  */
                /*     target: content */
                /*     onRefresh: { */
                /*         menu.trod = false */
                /*     } */
                /* } */
            },
            State {
                name: "deme"
                when: menu.page == 2
                PropertyChanges { target: home; visible:false; }
                PropertyChanges { target: deme; visible:true; }
                PropertyChanges { target: proposal; visible:false; }
                PropertyChanges { target: vote; visible:false; }
                PropertyChanges { target: observe; visible:false; }
            },
            State {
                name: "proposal"
                when: menu.page == 3
                PropertyChanges { target: home; visible:false; }
                PropertyChanges { target: deme; visible:false; }
                PropertyChanges { target: proposal; visible:true; }
                PropertyChanges { target: vote; visible:false; }
                PropertyChanges { target: observe; visible:false; }
            },
            State {
                name: "vote"
                when: menu.page == 4
                PropertyChanges { target: home; visible:false; }
                PropertyChanges { target: deme; visible:false; }
                PropertyChanges { target: proposal; visible:false; }
                PropertyChanges { target: vote; visible:true; }
                PropertyChanges { target: observe; visible:false; }
            },
            State {
                name: "observe"
                when: menu.page == 5
                PropertyChanges { target: home; visible:false; }
                PropertyChanges { target: deme; visible:false; }
                PropertyChanges { target: proposal; visible:false; }
                PropertyChanges { target: vote; visible:false; }
                PropertyChanges { target: observe; visible:true; }
            }

        ]
    }

}


