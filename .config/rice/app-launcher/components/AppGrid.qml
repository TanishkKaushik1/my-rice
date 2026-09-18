import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    property var    filteredApps: []
    property int    appsRevision:  0
    property var safeApps: appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps : []
    onAppsRevisionChanged: console.log("AppGrid sees revision:", appsRevision, "filteredApps.length:", Array.isArray(filteredApps) ? filteredApps.length : "NOT ARRAY")
    property string searchQuery:  ""
    property bool   shown:        false
    property color  surface:          "#10140f"
    property color  fgColor:          "#e0e4db"
    property color  primary:          "#9fd49b"
    property color  surfaceContainer: "#1c211b"
    property color  primaryContainer: "#215025"
    property string activeFont:       "Inter Nerd Font"
    property bool   refreshing:       false

    signal searchChanged(string q)
    signal launchRequested(var app)
    signal closeRequested()
    signal refreshRequested()

    color: Qt.rgba(surface.r, surface.g, surface.b, 0.75)
    

    // Flat left edge to join SidePanel
    layer.enabled: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // ── Search bar + refresh button ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 22
            color: surfaceContainer
            border.color: searchField.activeFocus
                ? Qt.rgba(primary.r, primary.g, primary.b, 0.7)
                : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin:  14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: "󰍉"
                    color: primary
                    font.family: activeFont
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 36
                    height: 44

                    Text {
                        visible: searchField.text === ""
                        text: "Search apps..."
                        color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.3)
                        font.pixelSize: 13
                        font.family: activeFont
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 13
                        font.family: activeFont
                        color: fgColor
                        focus: shown

                        onTextChanged: searchChanged(text)
                        Keys.onEscapePressed: closeRequested()
                        Keys.onReturnPressed: {
                            if (Array.isArray(filteredApps) && filteredApps.length > 0)
                                launchRequested(filteredApps[0])
                        }
                    }
                }
            }
        }

        // ── Refresh button ───────────────────────────────────────────────
        Rectangle {
            id: refreshBtn
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 22
            color: refreshArea.containsMouse
                ? Qt.rgba(primary.r, primary.g, primary.b, 0.18)
                : surfaceContainer
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            Text {
                id: refreshIcon
                anchors.centerIn: parent
                text: "󰑓"
                color: refreshing ? primary : fgColor
                font.family: activeFont
                font.pixelSize: 16
                opacity: refreshing ? 1.0 : 0.75

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                RotationAnimation {
                    id: spinAnim
                    target: refreshIcon
                    property: "rotation"
                    from: 0; to: 360
                    duration: 700
                    loops: Animation.Infinite
                    running: refreshing
                    onRunningChanged: if (!running) refreshIcon.rotation = 0
                }
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: refreshRequested()
            }
        }

        }

        // ── App count ─────────────────────────────────────────────────────────
        Text {
            text: (appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps.length : 0) + " apps"
            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.3)
            font.family: activeFont
            font.pixelSize: 10
            Layout.leftMargin: 4
        }

        // ── App grid ──────────────────────────────────────────────────────────
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridView {
                id: grid
                width: parent.width
                cellWidth:  Math.floor(width / 5)
                cellHeight: 110
                model: appsRevision >= 0 && Array.isArray(filteredApps) ? filteredApps : []
                clip: true

                // Staggered fade + rise-in whenever the model is (re)populated,
                // e.g. after a refresh swaps in a new filteredApps array.
                populate: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0; to: 1
                        duration: 220
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        properties: "y"
                        // 10px settle from slightly below final position
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                add: Transition {
                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 180 }
                    NumberAnimation { properties: "scale"; from: 0.85; to: 1; duration: 180; easing.type: Easing.OutBack }
                }

                remove: Transition {
                    NumberAnimation { properties: "opacity"; to: 0; duration: 120 }
                    NumberAnimation { properties: "scale"; to: 0.85; duration: 120 }
                }

                // Smoothly reflow remaining cards into new grid positions
                // when items are added/removed (e.g. search filtering).
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: AppCard {
                    width:  grid.cellWidth
                    height: grid.cellHeight
                    appData: modelData
                    fgColor:        fgColor
                    primary:        primary
                    primaryContainer: primaryContainer
                    activeFont:     activeFont
                    onClicked: launchRequested(modelData)
                }
            }
        }

    }

    // ── Reset search when hidden ──────────────────────────────────────────────
    onShownChanged: {
        if (!shown) searchField.text = ""
        else        searchField.forceActiveFocus()
    }
}
