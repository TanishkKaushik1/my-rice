import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// ── QUICK LAUNCHER "ADD APP" POPUP ──────────────────────────────────────────
// Top-level PanelWindow instantiated in shell.qml to prevent clipping from
// the 58px bar height.

PanelWindow {
    id: pickerWindow
    anchors { top: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.keyboardFocus: pickerWindow.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool open: false
    property var installedApps: []
    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property string activeFont: "Inter Nerd Font"

    signal appPicked(var app)
    signal requestClose()

    property string searchText: ""
    property var filteredApps: {
        if (searchText.trim().length === 0) return installedApps
        let q = searchText.toLowerCase()
        return installedApps.filter(a => a.name.toLowerCase().includes(q))
    }

    onOpenChanged: if (open) {
        searchText = ""
        searchInput.forceActiveFocus()
    }

    implicitHeight: open ? 370 : 0
    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        enabled: pickerWindow.open
        onClicked: pickerWindow.requestClose()
    }

    Rectangle {
        id: panel
        width: 250
        height: 340
        radius: 14
        color: pickerWindow.pillBg
        border.width: 1
        border.color: Qt.rgba(pickerWindow.accentColor.r, pickerWindow.accentColor.g, pickerWindow.accentColor.b, 0.55)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4

        opacity: pickerWindow.open ? 1 : 0
        scale: pickerWindow.open ? 1.0 : 0.94
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: parent.height * 0.35
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.045)
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            spacing: 10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Text {
                    text: "󰀻"
                    color: pickerWindow.accentColor
                    font.family: pickerWindow.activeFont
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Add app"
                    color: pickerWindow.fgColor
                    font.family: pickerWindow.activeFont
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: searchBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 30
                radius: 8
                color: Qt.rgba(1, 1, 1, searchInput.activeFocus ? 0.10 : 0.07)
                border.width: 1
                border.color: searchInput.activeFocus
                    ? Qt.rgba(pickerWindow.accentColor.r, pickerWindow.accentColor.g, pickerWindow.accentColor.b, 0.8)
                    : Qt.rgba(1, 1, 1, 0.08)
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    spacing: 6

                    Text {
                        text: "󰍉"
                        color: searchInput.activeFocus ? pickerWindow.accentColor : Qt.rgba(1, 1, 1, 0.4)
                        font.family: pickerWindow.activeFont
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: "Search apps…"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: pickerWindow.activeFont
                        font.pixelSize: 12
                        visible: searchInput.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: pickerWindow.fgColor
                    font.family: pickerWindow.activeFont
                    font.pixelSize: 12
                    clip: true
                    text: pickerWindow.searchText
                    onTextChanged: pickerWindow.searchText = text
                    focus: pickerWindow.open
                }
            }

            Rectangle { 
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }
        }

        ListView {
            id: appList
            anchors.top: header.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            clip: true
            spacing: 2
            model: pickerWindow.filteredApps

            ScrollBar.vertical: ScrollBar {
                policy: appList.contentHeight > appList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: rowDelegate
                width: ListView.view.width
                height: 34
                color: "transparent"
                radius: 8

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Rectangle {
                        width: 22; height: 22; radius: 6
                        color: Qt.rgba(1, 1, 1, 0.07)
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            id: rowIcon
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: modelData && modelData.icon ? Quickshell.iconPath(modelData.icon, "") : ""
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: rowIcon.status !== Image.Ready
                            text: modelData && modelData.name && modelData.name.length > 0
                                  ? modelData.name.substring(0, 1).toUpperCase() : "?"
                            color: pickerWindow.fgColor
                            font.family: pickerWindow.activeFont
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: pickerWindow.fgColor
                        font.family: pickerWindow.activeFont
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: rowDelegate.width - 46
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.color = Qt.rgba(1, 1, 1, 0.09)
                    onExited:  parent.color = "transparent"
                    onClicked: {
                        pickerWindow.appPicked(modelData)
                        pickerWindow.requestClose()
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: pickerWindow.installedApps.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰚌"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font.family: pickerWindow.activeFont
                    font.pixelSize: 20
                }
                Text {
                    horizontalAlignment: Text.AlignHCenter
                    text: "No apps found —\nchecked /usr/share/applications\nand ~/.local/share/applications"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: pickerWindow.activeFont
                    font.pixelSize: 11
                }
            }

            Text {
                anchors.centerIn: parent
                visible: pickerWindow.installedApps.length > 0 && pickerWindow.filteredApps.length === 0
                text: "No matches for “" + pickerWindow.searchText + "”"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.family: pickerWindow.activeFont
                font.pixelSize: 11
            }
        }
    }
}