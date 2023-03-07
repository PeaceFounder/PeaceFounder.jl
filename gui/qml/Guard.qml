import QtQuick 2.15
import QtQuick.Controls 2.15

//import QtQuick.Studio.Components 1.0
//import Qt5Compat.GraphicalEffects
//import QtQuick.Layouts

import "."

AppPage {
    
    anchors.fill: parent

    title : "Guard"
    subtitle : "Guard your vote"

    VScrollBar {
        
        contentY : view.contentItem.contentY
        contentHeight : view.contentHeight

    }
    
    ScrollView {
        
        id : view

        anchors.fill : parent
        contentWidth : parent.width

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        Column {

            width : parent.width
            spacing : 21

            GuardStatus {
                
            }
            
            Text {

                anchors.horizontalCenter : parent.horizontalCenter
                width : parent.width * 0.75

                wrapMode : Text.WordWrap

                font.weight : Font.Light
                
                lineHeight : 1.5

                color : Style.textPrimary //"#D9A3A3"

                text : "Perhaps the guardian or collector acted maliciously, or the adversary obtained their credentials, which assured that the vote had been successfully recorded, whereas, in reality, it made to a black hole.

If the local device can be trusted, you can use a third-party device and go to the ballot box to check the current ledger commit. If the root matches with the one you have, it’s settled. Behind the scenes, this will also detect your credential theft after the tally is published in situations your credentials have leaked.

TIP: use a refresh button to get the most recent commit, and consider using a TOR browser if you do that right away to preserve your anonymity.

If your device is infected with malware, you can detect that. Take note of the receipt now and wait until the elections end and the tally with all votes is published. Look in the ledger and find record 9. Check that it was cast at the time you cast it, that it was made in the final count, that pseudonyms match, and that the vote is cast as intended.
"

            }

            Item { 
                height : 150
                width : parent.width 
            }

        }
    }
}
