import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ── AGENDA + CLIPBOARD VAULT CARD ───────────────────────────────────────────
// Left-edge sibling to the Music Pill. Same glass card language, same
// hover-snap behavior is expected to be wired around this in shell.qml.
//
// All colors are passed in as properties from root — sourced from matugen —
// never hardcoded here. Only pillBg keeps the fixed alpha-black wash.
//
// NOTE ON EMOJI GLYPHS: the emoji picker below renders emoji characters
// directly as text. To get colored emoji glyphs instead of empty boxes,
// install a color emoji font, e.g. on Arch:
//     sudo pacman -S noto-fonts-emoji
// on Debian/Ubuntu:
//     sudo apt install fonts-noto-color-emoji
// then make sure fontconfig picks it up (fc-cache -f).
Item {
    id: root

    // ── COLORS (from matugen via root) ─────────────────────────────────────
    property color pillBg:      "#99000000"
    property color fgColor
    property color accentColor
    property color errorColor
    property color btColor
    property string activeFont: "Inter Nerd Font"

    // ── DATA (owned here, persisted to disk) ────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME")
    property string tasksPath:   homeDir + "/.config/rice/agenda-tasks.json"
    property string alarmsPath:  homeDir + "/.config/rice/agenda-alarms.json"
    property string emojiDataPath: homeDir + "/.config/rice/emoji-data.json"
    property int    clipHistoryMax: 30
    property var    clipHistoryData: []  // [{ text, ts }], newest first
    property string clipSearchText: ""
    property int    nowTick: Math.floor(Date.now() / 1000)
    property int    vaultTabIndex: 0     // 0 = Timer, 1 = Alarm, 2 = Emoji
    property int    pickerHour: 0
    property int    pickerMinute: 0
    property string emojiSearchText: ""
    property string emojiMode: "emoji"   // "emoji" = normal emoji grid, "lenny" = lenny/kaomoji grid
    property string lennyDataPath: homeDir + "/.config/rice/bar/lenny-data.json"

    // Full lenny/kaomoji set loaded from disk at startup (see lennyDataPath
    // below), same pattern as emojiListAll — never hand-typed in code.
    property var lennyListAll: []

    ListModel { id: tasksModel }
    ListModel { id: clipModel }
    ListModel { id: alarmsModel }
    ListModel { id: emojiModel }

    // Full emoji set loaded from disk at startup (see emojiDataPath below)
    // instead of hand-typed in code. Populate that file once from a real
    // dataset — see the loader comment further down for how.
    property var emojiListAll: []

    readonly property int cardWidth: 440
    readonly property int emojiPanelWidth: 220
    readonly property int panelGap: 10

    width: cardWidth + panelGap + emojiPanelWidth
    implicitWidth: width
    implicitHeight: cardCol.implicitHeight

    readonly property color surfaceColor: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.06)
    readonly property color surfaceHover: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.10)
    readonly property color dividerColor: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.14)
    readonly property color mutedFg:      Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.55)

    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.nowTick = Math.floor(Date.now() / 1000) }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.cardWidth
        height: cardCol.implicitHeight
        radius: 12
        color: root.pillBg
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            spacing: 0

            // ── ZONE 1: QUICK-ACTION AGENDA ──────────────────────────────────
            ColumnLayout {
                id: agendaZone
                Layout.fillWidth: true
                Layout.margins: 14
                spacing: 10

                Text {
                    id: dateHeader
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    color: root.fgColor
                    font.family: root.activeFont
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true

                    Timer {
                        interval: 60000; running: true; repeat: true
                        onTriggered: dateHeader.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: root.surfaceColor
                    border.width: 1
                    border.color: taskInput.activeFocus
                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
                                  : "transparent"

                    TextInput {
                        id: taskInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.fgColor
                        font.family: root.activeFont
                        font.pixelSize: 13
                        clip: true
                        selectByMouse: true

                        Text {
                            text: "Quick add a task…"
                            color: root.mutedFg
                            font: taskInput.font
                            visible: taskInput.text.length === 0 && !taskInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onAccepted: {
                            const t = text.trim()
                            if (t.length === 0) return
                            tasksModel.insert(0, { taskText: t, done: false })
                            text = ""
                            root.saveTasks()
                        }
                    }
                }

                ListView {
                    id: taskList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 160)
                    clip: true
                    spacing: 2
                    model: tasksModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: RowLayout {
                        id: taskRow
                        width: taskList.width
                        spacing: 8
                        opacity: 1

                        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }

                        Rectangle {
                            id: checkbox
                            width: 16; height: 16
                            radius: 4
                            color: model.done ? root.accentColor : "transparent"
                            border.width: 1.5
                            border.color: model.done ? root.accentColor
                                                      : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.4)

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: {
                                    tasksModel.setProperty(index, "done", !model.done)
                                    if (model.done) {
                                        taskRow.opacity = 0
                                        removeTimer.taskIndex = index
                                        removeTimer.restart()
                                    }
                                    root.saveTasks()
                                }
                            }

                            Timer {
                                id: removeTimer
                                interval: 380
                                property int taskIndex: -1
                                onTriggered: {
                                    if (taskIndex >= 0 && taskIndex < tasksModel.count)
                                        tasksModel.remove(taskIndex)
                                    root.saveTasks()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.taskText
                            color: model.done ? root.mutedFg : root.fgColor
                            font.family: root.activeFont
                            font.pixelSize: 13
                            font.strikeout: model.done
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                height: 1
                color: root.dividerColor
            }

            // ── ZONE 2: CLIPBOARD VAULT ──────────────────────────────────────
            ColumnLayout {
                id: vaultZone
                Layout.fillWidth: true
                Layout.margins: 14
                spacing: 8

                // ── Header row: label · count · refresh · clear ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Clipboard"
                        color: root.mutedFg
                        font.family: root.activeFont
                        font.pixelSize: 11
                        font.capitalization: Font.AllUppercase
                    }

                    Rectangle {
                        visible: root.clipHistoryData.length > 0
                        radius: 7
                        height: 14
                        width: countText.implicitWidth + 10
                        color: root.surfaceColor
                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: root.clipHistoryData.length
                            color: root.mutedFg
                            font.family: root.activeFont
                            font.pixelSize: 9
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "⟳ Refresh"
                        color: refreshMouse.containsMouse ? root.accentColor : root.mutedFg
                        font.family: root.activeFont
                        font.pixelSize: 10
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            onClicked: root.refreshClipView()
                        }
                    }

                    Text {
                        text: "Clear"
                        visible: root.clipHistoryData.length > 0
                        color: clearMouse.containsMouse ? root.errorColor : root.mutedFg
                        font.family: root.activeFont
                        font.pixelSize: 10
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            onClicked: root.clearClipHistory()
                        }
                    }
                }

                // ── Clipboard search ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: 8
                    color: root.surfaceColor
                    border.width: 1
                    border.color: clipSearchInput.activeFocus
                                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
                                  : "transparent"

                    Text {
                        text: "⌕"
                        color: root.mutedFg
                        font.pixelSize: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: clipSearchInput
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.fgColor
                        font.family: root.activeFont
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true

                        Text {
                            text: "Search clipboard history…"
                            color: root.mutedFg
                            font: clipSearchInput.font
                            visible: clipSearchInput.text.length === 0 && !clipSearchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            root.clipSearchText = text
                            root.refreshClipView()
                        }
                    }
                }

                // ── Live clipboard stack (searchable, type-aware) ──
                ListView {
                    id: clipList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Math.max(contentHeight, 34), 180)
                    clip: true
                    spacing: 4
                    model: clipModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: clipList.width
                        height: model.kind === "code" ? 48 : 36
                        radius: 8
                        color: clipMouse.containsMouse ? root.surfaceHover : root.surfaceColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            // type-aware leading glyph / swatch
                            Rectangle {
                                visible: model.kind === "color"
                                width: 16; height: 16; radius: 4
                                color: model.kind === "color" ? model.clipText : "transparent"
                                border.width: 1
                                border.color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.25)
                            }
                            Text {
                                visible: model.kind !== "color"
                                text: model.kind === "url" ? "🔗" : (model.kind === "code" ? "▤" : "❐")
                                color: root.mutedFg
                                font.pixelSize: 12
                                Layout.preferredWidth: 16
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: model.clipText
                                    color: root.fgColor
                                    font.family: model.kind === "color" || model.kind === "code" ? "monospace" : root.activeFont
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: model.kind === "code"
                                    text: "+ " + model.extraLines + " more lines"
                                    color: root.mutedFg
                                    font.family: root.activeFont
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                text: root.relTime(model.ts)
                                color: root.mutedFg
                                font.family: root.activeFont
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: clipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.copyToClipboard(model.fullText)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: clipModel.count === 0
                        text: root.clipSearchText.length > 0 ? "No matches" : "Copy something to get started"
                        color: root.mutedFg
                        font.family: root.activeFont
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.dividerColor
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // ── Timer / Alarm segmented tab bar ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    radius: 8
                    color: root.surfaceColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 2

                        Repeater {
                            model: ["Timer", "Alarm"]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 7
                                color: root.vaultTabIndex === index ? root.accentColor : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.vaultTabIndex === index ? root.pillBg : root.mutedFg
                                    font.family: root.activeFont
                                    font.pixelSize: 11
                                    font.bold: root.vaultTabIndex === index
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.vaultTabIndex = index }
                            }
                        }
                    }
                }

                // ── TIMER PANEL ──
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.vaultTabIndex === 0
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.timerJustFinished ? "Time's up!" : root.fmtTime(root.timerRemaining)
                        color: root.timerJustFinished ? root.errorColor : root.fgColor
                        font.family: "monospace"
                        font.pixelSize: root.timerJustFinished ? 20 : 32
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: root.dividerColor
                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: root.accentColor
                            width: root.timerDuration > 0
                                   ? parent.width * (root.timerRemaining / root.timerDuration)
                                   : 0
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: [ { l: "-10m", s: -600 }, { l: "-5m", s: -300 }, { l: "-1m", s: -60 },
                                     { l: "+1m", s: 60 }, { l: "+5m", s: 300 }, { l: "+10m", s: 600 } ]
                            delegate: Rectangle {
                                width: 44; height: 24; radius: 6
                                color: chipMouse.containsMouse ? root.surfaceHover : root.surfaceColor
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.l
                                    color: root.fgColor
                                    font.family: root.activeFont
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.addTimerSeconds(modelData.s)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Rectangle {
                            width: 90; height: 30; radius: 8
                            color: root.accentColor
                            opacity: startMouse.containsMouse ? 0.85 : 1
                            Text {
                                anchors.centerIn: parent
                                text: root.timerRunning ? "Pause" : (root.timerJustFinished ? "Restart" : "Start")
                                color: root.pillBg
                                font.family: root.activeFont
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                id: startMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.toggleTimer()
                            }
                        }

                        Rectangle {
                            width: 30; height: 30; radius: 8
                            color: root.surfaceColor
                            Text {
                                anchors.centerIn: parent
                                text: "↺"
                                color: root.fgColor
                                font.pixelSize: 15
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.resetTimer() }
                        }
                    }
                }

                // ── ALARM PANEL ──
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.vaultTabIndex === 1
                    spacing: 6

                    ListView {
                        id: alarmList
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(Math.max(contentHeight, 1), 110)
                        clip: true
                        spacing: 4
                        model: alarmsModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: alarmList.width
                            height: 32
                            radius: 8
                            color: root.surfaceColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: model.time
                                    color: model.enabled ? root.fgColor : root.mutedFg
                                    font.family: "monospace"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 32; height: 16; radius: 8
                                    color: model.enabled ? root.accentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.2)
                                    Rectangle {
                                        width: 12; height: 12; radius: 6
                                        color: root.pillBg
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: model.enabled ? parent.width - width - 2 : 2
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            alarmsModel.setProperty(index, "enabled", !model.enabled)
                                            root.saveAlarms()
                                        }
                                    }
                                }

                                Text {
                                    text: "×"
                                    color: root.mutedFg
                                    font.pixelSize: 15
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: { alarmsModel.remove(index); root.saveAlarms() }
                                    }
                                }
                            }
                        }
                    }

                    // ── Scrollable hour : minute picker (Android-style wheels) ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 30
                            radius: 8
                            color: root.surfaceColor
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 4

                            ListView {
                                id: hourWheel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: 24
                                delegate: Item {
                                    width: hourWheel.width
                                    height: hourWheel.rowH
                                    property real dist: Math.abs(hourWheel.currentIndex - index)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String(modelData).padStart(2, '0')
                                        color: root.fgColor
                                        font.family: "monospace"
                                        font.pixelSize: parent.dist < 0.5 ? 18 : 14
                                        font.bold: parent.dist < 0.5
                                        opacity: parent.dist < 0.5 ? 1 : (parent.dist < 1.5 ? 0.5 : 0.25)
                                    }
                                }
                                readonly property int rowH: 30
                                preferredHighlightBegin: rowH
                                preferredHighlightEnd: rowH * 2
                                highlightRangeMode: ListView.StrictlyEnforceRange
                                snapMode: ListView.SnapOneItem
                                flickDeceleration: 4000
                                onCurrentIndexChanged: root.pickerHour = currentIndex
                                topMargin: rowH
                                bottomMargin: rowH
                            }

                            Text {
                                text: ":"
                                color: root.fgColor
                                font.family: "monospace"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            ListView {
                                id: minuteWheel
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: 60
                                delegate: Item {
                                    width: minuteWheel.width
                                    height: minuteWheel.rowH
                                    property real dist: Math.abs(minuteWheel.currentIndex - index)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String(modelData).padStart(2, '0')
                                        color: root.fgColor
                                        font.family: "monospace"
                                        font.pixelSize: parent.dist < 0.5 ? 18 : 14
                                        font.bold: parent.dist < 0.5
                                        opacity: parent.dist < 0.5 ? 1 : (parent.dist < 1.5 ? 0.5 : 0.25)
                                    }
                                }
                                readonly property int rowH: 30
                                preferredHighlightBegin: rowH
                                preferredHighlightEnd: rowH * 2
                                highlightRangeMode: ListView.StrictlyEnforceRange
                                snapMode: ListView.SnapOneItem
                                flickDeceleration: 4000
                                onCurrentIndexChanged: root.pickerMinute = currentIndex
                                topMargin: rowH
                                bottomMargin: rowH
                            }

                            Rectangle {
                                width: 44; height: 30; radius: 8
                                color: root.accentColor
                                opacity: wheelAddMouse.containsMouse ? 0.85 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Add"
                                    color: root.pillBg
                                    font.family: root.activeFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                MouseArea {
                                    id: wheelAddMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.addAlarmTime(
                                        String(root.pickerHour).padStart(2, '0') + ":" +
                                        String(root.pickerMinute).padStart(2, '0'))
                                }
                            }
                        }
                    }

                    // ── Manual entry fallback ──
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: root.surfaceColor
                        border.width: 1
                        border.color: alarmInput.activeFocus
                                      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
                                      : "transparent"

                        TextInput {
                            id: alarmInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.fgColor
                            font.family: "monospace"
                            font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            maximumLength: 5

                            Text {
                                text: "or type hh:mm — press Enter"
                                color: root.mutedFg
                                font.family: root.activeFont
                                font.pixelSize: 11
                                visible: alarmInput.text.length === 0 && !alarmInput.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            onAccepted: {
                                if (root.addAlarmTime(text.trim())) text = ""
                            }
                        }
                    }
                }

            }
        }
    }

    // ── EMOJI PICKER: separate flyout card to the right of the vault ────────
    // Sibling panel (not a tab) so it reads like a companion popup, matching
    // the mock: [Search Emoji] box up top, grid below. Always shown next to
    // the vault (not a toggle) so it opens whenever the card is on screen.

    Rectangle {
        id: emojiPanel
        anchors.left: card.right
        anchors.leftMargin: root.panelGap
        anchors.top: card.top
        width: root.emojiPanelWidth
        height: card.height
        radius: 12
        color: root.pillBg
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // ── MODE TOGGLE: Emoji ⇄ Lenny/Kaomoji ──────────────────────────
            Rectangle {
                id: modeToggle
                Layout.fillWidth: true
                height: 26
                radius: 8
                color: root.surfaceColor

                Rectangle {
                    id: modeThumb
                    width: parent.width / 2
                    height: parent.height
                    radius: 8
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                    x: root.emojiMode === "lenny" ? parent.width / 2 : 0
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "Emoji"
                        color: root.fgColor
                        font.family: root.activeFont
                        font.pixelSize: 11
                        font.bold: root.emojiMode === "emoji"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.emojiMode !== "emoji") root.toggleEmojiMode()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "( ͡° ͜ʖ ͡°)"
                        color: root.fgColor
                        font.family: root.activeFont
                        font.pixelSize: 11
                        font.bold: root.emojiMode === "lenny"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.emojiMode !== "lenny") root.toggleEmojiMode()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 8
                color: root.surfaceColor
                border.width: 1
                border.color: emojiSearchInput.activeFocus
                              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
                              : "transparent"

                Text {
                    text: "⌕"
                    color: root.mutedFg
                    font.pixelSize: 14
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: emojiSearchInput
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.fgColor
                    font.family: root.activeFont
                    font.pixelSize: 12
                    clip: true
                    selectByMouse: true

                    Text {
                        text: root.emojiMode === "lenny" ? "Search Lenny" : "Search Emoji"
                        color: root.mutedFg
                        font: emojiSearchInput.font
                        visible: emojiSearchInput.text.length === 0 && !emojiSearchInput.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    onTextChanged: {
                        root.emojiSearchText = text
                        root.refreshEmojiView()
                    }
                }
            }

            GridView {
                id: emojiGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: root.emojiMode === "lenny" ? root.emojiPanelWidth - 28 : 40
                cellHeight: root.emojiMode === "lenny" ? 34 : 36
                model: emojiModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: emojiGrid.cellWidth - (root.emojiMode === "lenny" ? 4 : 4)
                    height: root.emojiMode === "lenny" ? 30 : 32
                    radius: 6
                    color: emojiMouse.containsMouse ? root.surfaceHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: model.glyph
                        color: root.fgColor
                        font.pixelSize: root.emojiMode === "lenny" ? 13 : 18
                        font.family: root.emojiMode === "lenny" ? root.activeFont : ""
                        elide: Text.ElideRight
                        width: parent.width - 6
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        id: emojiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.copyToClipboard(model.glyph)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: emojiModel.count === 0
                    text: "No matches"
                    color: root.mutedFg
                    font.family: root.activeFont
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.emojiMode === "emoji"
                text: "Needs a color-emoji font — see top of file."
                color: root.mutedFg
                font.family: root.activeFont
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }

        Component.onCompleted: root.refreshEmojiView()
    }

    // ── PERSISTENCE: TASKS ──────────────────────────────────────────────────
    function saveTasks() {
        let arr = []
        for (let i = 0; i < tasksModel.count; i++) {
            const item = tasksModel.get(i)
            arr.push({ taskText: item.taskText, done: item.done })
        }
        tasksSaveProc.pendingJson = JSON.stringify(arr)
        tasksSaveProc.running = true
    }

    Process {
        id: tasksLoadProc
        command: ["sh", "-c", "cat \"" + root.tasksPath + "\" 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim())
                    if (Array.isArray(parsed)) {
                        tasksModel.clear()
                        for (const t of parsed) tasksModel.append({ taskText: t.taskText, done: !!t.done })
                    }
                } catch (e) {
                    console.log("AgendaVault: task parse error", e)
                }
            }
        }
    }

    Process {
        id: tasksSaveProc
        property string pendingJson: "[]"
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"",
                  "_", pendingJson, root.tasksPath]
        running: false
    }

    // ── PERSISTENCE: ALARMS ─────────────────────────────────────────────────
    function saveAlarms() {
        let arr = []
        for (let i = 0; i < alarmsModel.count; i++) {
            const a = alarmsModel.get(i)
            arr.push({ time: a.time, enabled: a.enabled, lastFiredDate: a.lastFiredDate })
        }
        alarmsSaveProc.pendingJson = JSON.stringify(arr)
        alarmsSaveProc.running = true
    }

    Process {
        id: alarmsLoadProc
        command: ["sh", "-c", "cat \"" + root.alarmsPath + "\" 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim())
                    if (Array.isArray(parsed)) {
                        alarmsModel.clear()
                        for (const a of parsed)
                            alarmsModel.append({ time: a.time, enabled: !!a.enabled, lastFiredDate: a.lastFiredDate || "" })
                    }
                } catch (e) {
                    console.log("AgendaVault: alarm parse error", e)
                }
            }
        }
    }

    Process {
        id: alarmsSaveProc
        property string pendingJson: "[]"
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"",
                  "_", pendingJson, root.alarmsPath]
        running: false
    }

    // ── EMOJI DATA (loaded from disk, not hand-typed) ───────────────────────
    // Point emojiDataPath at a JSON file shaped like:
    //   [{"e":"😀","n":"grinning face smileys emotion"}, ...]
    // Easiest source: the `unicode-emoji-json` npm package's
    // data-by-emoji.json, converted once with a script like:
    //
    //   python3 -c "
    //   import json
    //   data = json.load(open('data-by-emoji.json', encoding='utf-8'))
    //   out = [{'e': g, 'n': (m['name']+' '+m['slug'].replace('_',' ')+' '+m['group']).lower()}
    //          for g, m in data.items()]
    //   json.dump(out, open('emoji-data.json','w', encoding='utf-8'), ensure_ascii=False)
    //   "
    //
    // then drop the resulting emoji-data.json at emojiDataPath. Falls back
    // to an empty list (picker just shows "No matches") if the file is missing.
    Process {
        id: emojiLoadProc
        command: ["sh", "-c", "cat \"" + root.emojiDataPath + "\" 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim())
                    if (Array.isArray(parsed)) {
                        root.emojiListAll = parsed
                        root.refreshEmojiView()
                    }
                } catch (e) {
                    console.log("AgendaVault: emoji data parse error", e)
                }
            }
        }
    }

    // ── LENNY / KAOMOJI DATA (loaded from disk, not hand-typed) ─────────────
    // Point lennyDataPath at a JSON file shaped like:
    //   [{"e":"( ͡° ͜ʖ ͡°)","n":"lenny smug"}, ...]
    // Easiest source: the `kaomoji-collection` npm package — 41,000+ kaomoji
    // across 535 categories, sourced from kaomojiya.org. Generate once with:
    //
    //   npm install kaomoji-collection
    //   node -e "
    //   const kc = require('kaomoji-collection');
    //   const out = [];
    //   for (const cat of kc.categories()) {
    //     for (const face of kc.list(cat)) out.push({ e: face, n: cat });
    //   }
    //   require('fs').writeFileSync('lenny-data.json', JSON.stringify(out));
    //   "
    //
    // then drop the resulting lenny-data.json at lennyDataPath. (For an
    // English-labeled alternative with a dedicated 'lenny' tag, see the
    // ekohrt/emoticon_kaomoji_dataset dataset on GitHub instead.) Falls back
    // to an empty list (picker just shows "No matches") if the file is missing.
    Process {
        id: lennyLoadProc
        command: ["sh", "-c", "cat \"" + root.lennyDataPath + "\" 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim())
                    if (Array.isArray(parsed)) {
                        root.lennyListAll = parsed
                        root.refreshEmojiView()
                    }
                } catch (e) {
                    console.log("AgendaVault: lenny data parse error", e)
                }
            }
        }
    }

    Component.onCompleted: {
        tasksLoadProc.running = true
        alarmsLoadProc.running = true
        emojiLoadProc.running = true
        lennyLoadProc.running = true
    }

    Timer { interval: 20000; running: true; repeat: true; onTriggered: root.checkAlarms() }

    function addAlarmTime(t) {
        if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(t)) return false
        for (let i = 0; i < alarmsModel.count; i++) {
            if (alarmsModel.get(i).time === t) return false
        }
        alarmsModel.append({ time: t, enabled: true, lastFiredDate: "" })
        let entries = []
        for (let k = 0; k < alarmsModel.count; k++) entries.push(alarmsModel.get(k))
        entries.sort((a, b) => a.time.localeCompare(b.time))
        alarmsModel.clear()
        for (const e of entries) alarmsModel.append({ time: e.time, enabled: e.enabled, lastFiredDate: e.lastFiredDate })
        root.saveAlarms()
        return true
    }

    function checkAlarms() {
        const now = new Date()
        const hh = String(now.getHours()).padStart(2, '0')
        const mm = String(now.getMinutes()).padStart(2, '0')
        const cur = hh + ":" + mm
        const today = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, '0') + "-" + String(now.getDate()).padStart(2, '0')

        let changed = false
        for (let i = 0; i < alarmsModel.count; i++) {
            const a = alarmsModel.get(i)
            if (a.enabled && a.time === cur && a.lastFiredDate !== today) {
                alarmsModel.setProperty(i, "lastFiredDate", today)
                changed = true
                notifyProc.pendingTitle = "Alarm"
                notifyProc.pendingBody = "It's " + cur
                notifyProc.running = true
            }
        }
        if (changed) root.saveAlarms()
    }

    // ── TIMER STATE ──────────────────────────────────────────────────────────
    property int  timerDuration: 300
    property int  timerRemaining: 300
    property bool timerRunning: false
    property bool timerJustFinished: false

    Timer {
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: {
            if (root.timerRemaining > 0) root.timerRemaining--
            if (root.timerRemaining === 0) {
                root.timerRunning = false
                root.timerJustFinished = true
                notifyProc.pendingTitle = "Timer done"
                notifyProc.pendingBody = "Your timer has finished."
                notifyProc.running = true
            }
        }
    }

    function fmtTime(s) {
        const m = Math.floor(s / 60)
        const sec = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function addTimerSeconds(s) {
        timerJustFinished = false
        if (!timerRunning) {
            timerDuration = Math.max(0, timerDuration + s)
            timerRemaining = timerDuration
        } else {
            timerRemaining = Math.max(0, timerRemaining + s)
            timerDuration = Math.max(timerDuration, timerRemaining)
        }
    }

    function toggleTimer() {
        if (timerJustFinished) {
            timerJustFinished = false
            timerRemaining = timerDuration
        }
        if (timerRemaining <= 0) return
        timerRunning = !timerRunning
    }

    function resetTimer() {
        timerRunning = false
        timerJustFinished = false
        timerRemaining = timerDuration
    }

    // ── NOTIFICATIONS (shared by timer + alarms) ────────────────────────────
    Process {
        id: notifyProc
        property string pendingTitle: ""
        property string pendingBody: ""
        command: ["sh", "-c",
                  "notify-send \"$1\" \"$2\" 2>/dev/null; (paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || canberra-gtk-play -i complete 2>/dev/null || true)",
                  "_", pendingTitle, pendingBody]
        running: false
    }

    // ── LIVE CLIPBOARD (wl-clipboard) ───────────────────────────────────────
    function copyToClipboard(text) {
        clipCopyProc.pendingText = text
        clipCopyProc.running = true
    }

    function clipKind(text) {
        if (text.indexOf("\n") !== -1) return "code"
        if (/^#([0-9A-Fa-f]{3}){1,2}$/.test(text)) return "color"
        if (/^https?:\/\//i.test(text)) return "url"
        return "text"
    }

    function relTime(ts) {
        const diff = root.nowTick - ts
        if (diff < 60) return "now"
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        return Math.floor(diff / 86400) + "d"
    }

    function pushClip(text) {
        const t = text.trim()
        if (t.length === 0) return
        if (clipHistoryData.length > 0 && clipHistoryData[0].text === t) return

        let arr = clipHistoryData.slice()
        arr.unshift({ text: t, ts: Math.floor(Date.now() / 1000) })
        if (arr.length > root.clipHistoryMax) arr = arr.slice(0, root.clipHistoryMax)
        clipHistoryData = arr
        refreshClipView()
    }

    function clearClipHistory() {
        clipHistoryData = []
        refreshClipView()
    }

    // Rebuilds the visible clip list from clipHistoryData + current search.
    // Multi-line copies ("code") only show their first line plus a
    // "+N more lines" hint instead of dumping every line into the pill.
    function refreshClipView() {
        clipModel.clear()
        const q = clipSearchText.trim().toLowerCase()
        for (const entry of clipHistoryData) {
            if (q.length > 0 && entry.text.toLowerCase().indexOf(q) === -1) continue
            const kind = root.clipKind(entry.text)
            let display, extraLines = 0
            if (kind === "code") {
                const lines = entry.text.split("\n").filter(l => l.trim().length > 0)
                display = lines[0].length > 60 ? lines[0].slice(0, 60) + "…" : lines[0]
                extraLines = lines.length - 1
            } else {
                display = entry.text.length > 140 ? entry.text.slice(0, 140) + "…" : entry.text
            }
            clipModel.append({ clipText: display, fullText: entry.text, ts: entry.ts, kind: kind, extraLines: extraLines })
        }
    }

    // Rebuilds the emoji grid from the search box against whichever list is
    // active (emojiListAll for normal emoji, lennyListAll for lenny/kaomoji).
    function refreshEmojiView() {
        emojiModel.clear()
        const q = emojiSearchText.trim().toLowerCase()
        const source = root.emojiMode === "lenny" ? root.lennyListAll : root.emojiListAll
        for (const em of source) {
            if (q.length > 0 && em.n.indexOf(q) === -1) continue
            emojiModel.append({ glyph: em.e })
        }
    }

    function toggleEmojiMode() {
        emojiMode = (emojiMode === "lenny") ? "emoji" : "lenny"
        refreshEmojiView()
    }

    Process {
        id: clipCopyProc
        property string pendingText: ""
        command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", pendingText]
        running: false
    }

    // Watches the Wayland clipboard for changes. wl-paste --watch fires its
    // command once per change; that command just prints a marker line (never
    // the clipboard content itself), which triggers clipReadProc to fetch the
    // FULL current clipboard in one shot via StdioCollector. This is what
    // keeps a multi-line/code copy as a single history entry instead of
    // getting split into one entry per line.
    Process {
        id: clipWatchProc
        command: ["sh", "-c", "wl-paste --type text --watch sh -c 'echo _'"]
        running: true
        stdout: SplitParser {
            onRead: data => { clipReadProc.running = false; clipReadProc.running = true }
        }
        stderr: SplitParser {
            onRead: data => console.log("AgendaVault clip watch stderr:", data)
        }
    }

    Process {
        id: clipReadProc
        command: ["wl-paste", "--no-newline", "--type", "text"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.pushClip(text)
        }
    }
}
