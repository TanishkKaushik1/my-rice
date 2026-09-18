import QtQuick
import QtQuick.Controls
import QtQuick.Window // Required to track if the app window is open

Rectangle {
    id: card

    // ── Public ────────────────────────────────────────────────────────────
    property string workshopId:    ""
    property string title:         ""
    property string wallpaperType: ""
    property string previewPath:   ""
    property string folderPath:    ""

    signal applyRequested(string workshopId, string wallpaperPath, string previewPath)
    signal deleteRequested(string workshopId, string folderPath)
    signal settingsRequested(string workshopId, string folderPath, string previewPath)

    property bool isHovered: cardMouse.containsMouse

    radius: 12
    color:        isHovered ? "#1a1a1a" : "transparent"
    border.color: isHovered ? "#444444" : "#2a2a30"
    border.width: 1
    clip: true
    Behavior on color        { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    property bool _sourceReady: false

    Timer {
        id: loadDelay
        interval: Math.min(50 + (typeof index !== "undefined" ? index * 18 : 0), 1200)
        running: true
        repeat: false
        onTriggered: card._sourceReady = true
    }

    // Main click area covers the whole card
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            } else {
                card.applyRequested(card.workshopId, card.folderPath, card.previewPath)
                card.settingsRequested(card.workshopId, card.folderPath, card.previewPath)
            }
        }
    }

    Menu {
        id: contextMenu
        width: 140

        background: Rectangle {
            color: "#121215"; border.color: "#2a2a2a"; border.width: 1; radius: 8
        }

        MenuItem {
            id: delItem
            width: 140; height: 34
            contentItem: Item {
                anchors.fill: parent
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12; spacing: 10
                    Text { text: "✕"; color: "#ef4444"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Delete"; color: "#ef4444"; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            background: Rectangle {
                anchors.fill: parent; anchors.margins: 4
                color: delItem.highlighted ? "#ef444433" : "transparent"; radius: 6
            }
            onTriggered: card.deleteRequested(card.workshopId, card.folderPath)
        }
    }

    // ── Preview image ──────────────────────────────────────────────────────
    Rectangle {
        id: imgContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        height: parent.height - 64
        color: "#050505"
        radius: 8
        clip: true

        Column {
            id: placeholder
            anchors.centerIn: parent; spacing: 8
            visible: !preview.visible

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.wallpaperType === "video" ? "▶"
                    : card.wallpaperType === "web"   ? "◈"
                    : card.wallpaperType === "scene" ? "✦" : "◇"
                color: "#333333"; font.pixelSize: 28
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.wallpaperType.toUpperCase()
                color: "#333333"; font.pixelSize: 9; font.family: "monospace"
                font.letterSpacing: 2; visible: card.wallpaperType !== ""
            }
        }

        AnimatedImage {
            id: preview
            anchors.fill: parent
            source: card._sourceReady && card.previewPath !== ""
                    ? ("file://" + card.previewPath)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: false          
            mipmap: false          
            
            // Plays ONLY when the Switcher window is actively visible on screen
            playing: Window.window ? Window.window.visible : false
            
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            color: "#050505"
            opacity: preview.status === Image.Ready ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
            width: typeLabel.width + 12; height: 20; radius: 4
            color: "#000000cc"
            border.color: "#333333"
            border.width: 1
            visible: card.wallpaperType !== ""
            
            Text {
                id: typeLabel; anchors.centerIn: parent
                text: card.wallpaperType.toUpperCase()
                color: "#ffffff"
                font.pixelSize: 8; font.letterSpacing: 1.5
                font.family: "monospace"; font.weight: Font.Bold
            }
        }
    }

    // ── Bottom info strip ──────────────────────────────────────────────────
    Item {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; height: 52
        anchors.leftMargin: 12; anchors.rightMargin: 12

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; spacing: 4

            Text {
                width: parent.width; text: card.title
                color: card.isHovered ? "#ffffff" : "#cccccc"
                font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                text: "ID: " + card.workshopId
                color: "#666666"; font.pixelSize: 10
                font.family: "monospace"; font.letterSpacing: 0.5
            }
        }
    }
}