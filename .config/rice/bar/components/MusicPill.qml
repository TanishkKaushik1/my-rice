import QtQuick

Item {
    id: rootPill
    property color  accentColor: "#9fd49b"
    property color  fgColor:     "#e0e4db"
    property string activeFont:  "Inter Nerd Font"
    
    property string musicTitle:  ""
    property string musicPlayer: "Media"
    property var    visualizerData: []
    property bool   isPlaying:   false
    
    // New Properties
    property real   musicPosition: 0
    property real   musicLength: 1
    property real   sysVolume: 0.5
    property bool   sysMuted: false

    signal prevClicked
    signal playPauseClicked
    signal nextClicked
    signal volumeChanged(real newVolume)

    // Helper to format seconds into M:SS
    function formatTime(sec) {
        if (isNaN(sec) || sec < 0) return "0:00"
        let m = Math.floor(sec / 60)
        let s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    width: 400
    height: 185

    Rectangle {
        anchors.fill: parent
        color: "#99000000" 
        radius: 12         
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
        border.width: 1

        // ── TOP: App Name & Title ───────────────────────────────────────────
        Item {
            id: topSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 65
            
            Rectangle {
                id: appBadge
                width: Math.max(appNameText.width + 20, 40)
                height: 32
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15)
                radius: 6
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
                
                Text {
                    id: appNameText
                    anchors.centerIn: parent
                    text: musicPlayer
                    color: accentColor
                    font.family: activeFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Text {
                anchors.left: appBadge.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: musicTitle || "No Music Playing"
                color: fgColor
                font.family: activeFont
                font.pixelSize: 14 
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                lineHeight: 1.2
            }
        }

        // ── MIDDLE: Progress Bar ────────────────────────────────────────────
        Item {
            id: progressSection
            anchors.top: topSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30
            
            Text {
                id: currentTimeText
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: formatTime(musicPosition)
                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.7)
                font.family: activeFont
                font.pixelSize: 11
                width: 35
            }

            Rectangle {
                id: progressBarBg
                anchors.left: currentTimeText.right
                anchors.right: totalTimeText.left
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.1)

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: accentColor
                    // Clamp width between 0 and full width
                    width: Math.min(Math.max((musicPosition / musicLength) * parent.width, 0), parent.width)
                    Behavior on width { NumberAnimation { duration: 1000 } } // Smooth sliding
                }
            }

            Text {
                id: totalTimeText
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: formatTime(musicLength)
                color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.7)
                font.family: activeFont
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                width: 35
            }
        }

        Rectangle {
            id: hDivider
            anchors.top: progressSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            color: Qt.rgba(1, 1, 1, 0.1) 
        }

        // ── BOTTOM: Controls, Volume, Visualizer ────────────────────────────
        Item {
            id: bottomSection
            anchors.top: hDivider.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            // Media Controls
            Row {
                id: controlsRow
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒮"
                    color: prevMa.containsMouse ? fgColor : accentColor
                    font.family: activeFont; font.pixelSize: 22 
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: prevClicked() }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2 
                    text: isPlaying ? "󰏤" : "󰐊"
                    color: playMa.containsMouse ? fgColor : accentColor
                    font.family: activeFont; font.pixelSize: 28 
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { id: playMa; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: playPauseClicked() }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒭"
                    color: nextMa.containsMouse ? fgColor : accentColor
                    font.family: activeFont; font.pixelSize: 22
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -10; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nextClicked() }
                }
            }

            Rectangle {
                id: vDivider1
                anchors.left: controlsRow.right
                anchors.leftMargin: 16
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.topMargin: 12; anchors.bottomMargin: 12
                width: 1; color: Qt.rgba(1, 1, 1, 0.1) 
            }

            // PipeWire Volume Control
            Item {
                id: volumeSection
                anchors.left: vDivider1.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                height: 24

                Text {
                    id: volIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: sysMuted || sysVolume === 0 ? "󰖁" : "󰕾"
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.7)
                    font.family: activeFont
                    font.pixelSize: 16
                }

                Rectangle {
                    anchors.left: volIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)

                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: accentColor
                        width: parent.width * Math.min(Math.max(sysVolume, 0), 1)
                    }

                    // Interactive Slider
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10 // Easier to click
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            let newVol = Math.max(0, Math.min(1, mouse.x / width))
                            volumeChanged(newVol)
                        }
                        onPressed: (mouse) => {
                            let newVol = Math.max(0, Math.min(1, mouse.x / width))
                            volumeChanged(newVol)
                        }
                    }
                }
            }

            Rectangle {
                id: vDivider2
                anchors.left: volumeSection.right
                anchors.leftMargin: 16
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.topMargin: 12; anchors.bottomMargin: 12
                width: 1; color: Qt.rgba(1, 1, 1, 0.1) 
            }

            // Visualizer Array 
            Row {
                anchors.left: vDivider2.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                height: 36 

                Repeater {
                    model: visualizerData.length > 14 ? 14 : visualizerData.length
                    Rectangle {
                        width: 5 
                        height: Math.max(4, visualizerData[index] * 36)
                        radius: 2.5
                        color: accentColor
                        opacity: 0.9
                        anchors.bottom: parent.bottom 
                        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }
    }
}