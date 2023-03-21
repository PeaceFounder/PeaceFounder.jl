import QtQuick
import QtQuick.Window
import QtQuick.Controls

import Qt5Compat.GraphicalEffects

Window {
    id: app
    width: 550
    height: 700

    visible: true
    color: Style.pageBackground 
    title: "PeaceFounder"


    property var userDemes


    component DemeStatusType : QtObject {
        
        property string uuid
        property string title
        property string demeSpec
        property int memberIndex
        property int commitIndex
        property int memberCount
        
    }

    property DemeStatusType demeStatus : DemeStatusType { }


    component ProposalMetadataType : QtObject {

        property int index
        property string title
        property string description
        property int stateAnchor
        property int voterCount

    }
    
    property ProposalMetadataType proposalMetadata : ProposalMetadataType { }


    component ProposalStatusType : QtObject {

        property bool isVotable
        property bool isCast
        property bool isTallied
        property string timeWindowShort
        property string timeWindowLong
        property int castCount

    }

    property ProposalStatusType proposalStatus : ProposalStatusType { }
    

    component GuardStatusType : QtObject {

        property string pseudonym
        property string timestamp
        property int castIndex

        property int commitIndex
        property string commitRoot

    }

    property GuardStatusType guardStatus : GuardStatusType { }
    

    property var demeProposals
    property var proposalBallot


    signal castBallot
    signal resetBallot

    signal setDeme(string uuid)
    signal setProposal(int index)
    
    signal refreshHome
    signal refreshDeme
    signal refreshProposal

    signal addDeme(string invite)
    

    property int page : 1 


    Item {

        id : content
        anchors.fill : parent

        Home {
            id : home
            state : "home"

            userDemes : app.userDemes

            onRefresh : app.refreshHome() 

            onDemeCard : uuid => {
                app.setDeme(uuid)
                app.page = 2
            }
        }


        Deme {
            id : deme
            state : "deme"
            onBack : app.page = 1

            demeUUID : app.demeStatus.uuid
            subtitle : app.demeStatus.title
            demeProposals : app.demeProposals

            demeSpec : app.demeStatus.demeSpec
            memberIndex : app.demeStatus.memberIndex
            commitIndex : app.demeStatus.commitIndex
            memberCount : app.demeStatus.memberCount


            onProposal : index => {
                app.setProposal(index)
                app.page = 3
            }

            onTally : index => {
                console.log("Tally not implemented")
                app.setProposal(index)
                app.page = 3
            }

            onVote : index => {
                app.setProposal(index)
                app.page = 4
            }

        }


        Proposal {

            id : proposal
            state : "proposal"
            onBack : app.page = 2

            proposalIndex : app.proposalMetadata.index
            subtitle : app.proposalMetadata.title
            description : app.proposalMetadata.description
            stateAnchor : app.proposalMetadata.stateAnchor
            voterCount : app.proposalMetadata.voterCount

            castCount : app.proposalStatus.castCount
            isCast : app.proposalStatus.isCast
            isTallied : app.proposalStatus.isTallied
            isVotable : app.proposalStatus.isVotable
            timeWindowLong : app.proposalStatus.timeWindowLong
            
            onVote : app.page = 4
            onGuard : app.page = 5
        }


        Ballot {
            id : vote
            state : "vote"
            onBack : app.page = 3


            subtitle : app.proposalMetadata.title
            model : app.proposalBallot

            onCast : {
                
                app.castBallot()

                // To cover errror states I will do a pattern matching with states 
                // on a new castStatus property
                app.resetBallot()
                app.page = 5
                                
            }

            onTrash : {
                app.resetBallot()
            }

        }

        Guard {
            id : observe
            state : "observe"
            onBack : app.page = 3

            demeUUID : app.demeStatus.uuid
            proposalIndex : app.proposalMetadata.index
            subtitle : app.proposalMetadata.title

            pseudonym : app.guardStatus.pseudonym
            timestamp : app.guardStatus.timestamp
            castIndex : app.guardStatus.castIndex

            commitIndex : app.guardStatus.commitIndex
            commitRoot : app.guardStatus.commitRoot
            
        }

    }
        


    Rectangle {
        id: rect
        anchors.fill: fastBlur
        color: Style.stepperBackground 
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
        radius: 32
        opacity: 0.55
        source: ShaderEffectSource {
            sourceItem: content
            sourceRect: Qt.rect(0, app.height - fastBlur.height, fastBlur.width, fastBlur.height)
        }
    }


    StepperMenu {
        id: menu
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 45

        page : app.page

        trod : !(app.proposalMetadata.index == 0)
        votable : app.proposalStatus.isVotable 
        observable : app.proposalStatus.isCast

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -140

        onHome: {
            app.page = 1
        }

        onDeme: {
            if (trod) {
                app.page = 2
            }
        }

        onProposal: {
            if (trod) {
                app.page = 3
            }
        }

        onVote: {
            if (votable) {
                app.page = 4
            }
        }

        onObserve: {
            if (observable) {
                app.page = 5
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
