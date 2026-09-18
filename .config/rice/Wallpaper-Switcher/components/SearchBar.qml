import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property alias text: input.text

    height: 34
    radius: 6
    color: input.activeFocus ? "#1a1a1a" : "transparent"
    border.color: input.activeFocus ? "#ffffff" : "#2a2a2a"
    border.width: 1

    Behavior on color        { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: "⌕"
            color: input.activeFocus ? "#ffffff" : "#666666"
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        TextInput {
            id: input
            width: parent.width - 40
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: 12
            font.family: "monospace"
            font.letterSpacing: 0.3
            selectionColor: "#444444"
            selectedTextColor: "#ffffff"
            clip: true

            // Placeholder text
            Text {
                anchors.fill: parent
                text: "Search wallpapers by name or ID…"
                color: "#666666"
                font.pixelSize: 12
                font.family: "monospace"
                font.letterSpacing: 0.3
                visible: input.text === "" && !input.activeFocus
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Clear button
        Text {
            text: "✕"
            color: clearHover.containsMouse ? "#ffffff" : "#666666"
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text !== ""
            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: clearHover }
            TapHandler { onTapped: input.text = "" }
        }
    }

    // Click anywhere on the bar to focus
    TapHandler { onTapped: input.forceActiveFocus() }
}