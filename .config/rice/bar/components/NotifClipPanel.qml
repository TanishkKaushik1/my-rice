import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    property bool   panelOpen:   false
    property color  accentColor: "#9fd49b"
    property color  fgColor:     "#e0e4db"
    property color  errorColor:  "#ffb4ab"
    property string activeFont:  "Inter Nerd Font"

    signal requestClose()

    // Deterministic per-app accent so recurring apps are visually recognizable
    // at a glance without reading the label.
    function appAccent(name) {
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = (hash * 31 + name.charCodeAt(i)) & 0xffffffff
        }
        var hue = Math.abs(hash) % 360
        return Qt.hsla(hue / 360, 0.5, 0.68, 1.0)
    }

    // ── Notifications ──────────────────────────────────────────────────────────
    property var notifEntries: []

    property var _notifProc: Process {
        id: _notifProc
        // Python script resolving dynamic environment directories and history locations
        command: ["sh", "-c",
            "python3 -c \"\n" +
            "import json,os,glob\n" +
            "cache_dir=os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache'))\n" +
            "f=os.path.join(cache_dir, 'rice', 'notif-history.json')\n" +
            "if not os.path.exists(f):\n" +
            " matches=glob.glob(os.path.join(cache_dir, '*', 'notif-history.json'))\n" +
            " if matches: f=matches[0]\n" +
            "pics=os.environ.get('XDG_PICTURES_DIR', os.path.expanduser('~/Pictures'))\n" +
            "screenshot_dir=os.environ.get('XDG_SCREENSHOTS_DIR', os.path.join(pics, 'Screenshots'))\n" + 
            "def get_latest():\n" +
            " files=glob.glob(os.path.join(screenshot_dir, '*.png'))+glob.glob(os.path.join(screenshot_dir, '*.jpg'))\n" +
            " return max(files, key=os.path.getmtime) if files else ''\n" +
            "try:\n" +
            " seen=set()\n" +
            " for n in json.load(open(f)):\n" +
            "  s=' '.join(str(n.get('summary') or '').splitlines())\n" +
            "  b=' '.join(str(n.get('body') or '').splitlines())\n" +
            "  a=str(n.get('appName') or n.get('app-name') or '')\n" +
            "  i=str(n.get('icon-path') or n.get('image-path') or n.get('image') or n.get('icon') or n.get('appIcon') or n.get('app-icon') or '')\n" +
            "  if i.startswith('file://'): i = i[7:]\n" +
            "  if not i.startswith('/'):\n" +
            "   if 'screenshot' in s.lower() or 'screenshot' in a.lower(): i = get_latest()\n" +
            "   else: i = ''\n" + 
            "  if a or i or s:\n" +
            "   line = s+';;'+b+';;'+a+';;'+i\n" +
            "   if line not in seen:\n" +
            "    seen.add(line)\n" +
            "    print(line)\n" +
            "except: pass\n" +
            "\""
        ]
        running: false
        onExited: (c,s) => { running = false }
        stdout: SplitParser {
            property string buf: ""
            onRead: data => { buf += data + "\n" }
        }
        onRunningChanged: {
            if (!running && stdout.buf !== "") {
                var lines = stdout.buf.trim().split("\n").filter(l => l.trim() !== "" && l.includes(";;"))
                root.notifEntries = lines
                stdout.buf = ""
            }
        }
    }

    property var _dismissAll: Process {
        id: _dismissAll
        command: ["sh", "-c",
            "makoctl dismiss --all 2>/dev/null;" +
            "cache_dir=\"${XDG_CACHE_HOME:-$HOME/.cache}\";" +
            "for f in \"$cache_dir\"/*/notif-history.json \"$cache_dir\"/notif-history.json; do " +
            "  [ -f \"$f\" ] && echo '[]' > \"$f\"; " +
            "done"
        ]
        running: false
        onExited: (c,s) => { running = false }
    }

    property var _notifCopy: Process {
        id: _notifCopy
        running: false
        onExited: (c,s) => { running = false }
    }

    property var _deleteProc: Process {
        id: _deleteProc
        running: false
        onExited: (c,s) => { running = false }
    }

    function copyContent(imgPath, textContent) {
        if (imgPath !== "" && imgPath.startsWith("/")) {
            _notifCopy.command = ["bash", "-c", "wl-copy -t image/png < \"" + imgPath + "\""]
        } else {
            _notifCopy.command = [
                "python3", "-c",
                "import sys,subprocess; subprocess.run(['wl-copy'], input=sys.argv[1].encode())",
                textContent
            ]
        }
        _notifCopy.running = false
        _notifCopy.running = true
    }

    function deleteContent(imgPath) {
        if (imgPath !== "" && imgPath.startsWith("/")) {
            _deleteProc.command = ["bash", "-c", "rm -f \"" + imgPath + "\""]
            _deleteProc.running = false
            _deleteProc.running = true
        }
    }

    onPanelOpenChanged: {
        if (panelOpen) {
            _notifProc.running = false; _notifProc.running = true
        }
    }

    // ── Per-screen window ─────────────────────────────────────────────────────
    property var _variants: Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWin
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.panelOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.panelOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
            }

            Rectangle {
                id: panelRect
                width: 368
                height: panelWin.height - 56 - 16
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 56; anchors.rightMargin: 5
                radius: 16
                clip: true

                // Subtle vertical gradient instead of flat fill — reads as glass, not slab.
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#f2101010" }
                    GradientStop { position: 1.0; color: "#f00a0a0a" }
                }
                border.color: Qt.rgba(1, 1, 1, 0.09)
                border.width: 1

                // Faint top highlight line for a glassy edge
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                MouseArea { anchors.fill: parent }

                // ── Header ─────────────────────────────────────────────
                Item {
                    id: headerArea
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 62

                    RowLayout {
                        anchors.left: parent.left; anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "Notifications"
                            color: root.fgColor
                            font.family: root.activeFont; font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        // Unread-count badge — real data, not decoration
                        Rectangle {
                            visible: root.notifEntries.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            width: countText.implicitWidth + 12; height: 18; radius: 9
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                            border.width: 1
                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.notifEntries.length
                                color: root.accentColor
                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                            }
                        }
                    }

                    Rectangle {
                        id: clearAllBtn
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearRow.implicitWidth + 20; height: 28; radius: 8
                        visible: root.notifEntries.length > 0
                        color: clearHover.pressed ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.22)
                             : clearHover.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                             : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰆴"
                                color: clearHover.containsMouse ? root.errorColor : Qt.rgba(1, 1, 1, 0.55)
                                font.family: root.activeFont; font.pixelSize: 11
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Text {
                                text: "Clear all"
                                color: clearHover.containsMouse ? root.errorColor : Qt.rgba(1, 1, 1, 0.55)
                                font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.Medium
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                _dismissAll.running = false
                                _dismissAll.running = true
                                root.notifEntries = []
                            }
                        }
                    }

                    // Gradient divider instead of a flat hairline
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.12) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }

                // ── Scrollable content ────────────────────────────────────────
                Flickable {
                    id: scroller
                    anchors {
                        top: headerArea.bottom
                        left: parent.left; right: parent.right; bottom: parent.bottom
                        topMargin: 14; leftMargin: 14; rightMargin: 14; bottomMargin: 14
                    }
                    clip: true
                    contentHeight: notifColumn.height
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        minimumSize: 0.08
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                        }
                    }

                    Column {
                        id: notifColumn
                        width: scroller.width
                        spacing: 10

                        add: Transition {
                            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { properties: "scale"; from: 0.97; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                        }

                        // Empty state
                        Item {
                            visible: root.notifEntries.length === 0
                            width: parent.width; height: 180

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰂚"
                                    color: Qt.rgba(1, 1, 1, 0.18)
                                    font.family: root.activeFont; font.pixelSize: 30
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "You're all caught up"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font.family: root.activeFont; font.pixelSize: 12; font.weight: Font.Medium
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "New notifications will show up here"
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    font.family: root.activeFont; font.pixelSize: 10
                                }
                            }
                        }

                        // Notification cards
                        Repeater {
                            model: root.notifEntries
                            delegate: Rectangle {
                                id: notifCard
                                required property var modelData
                                required property int index

                                property var    parts:    modelData.split(";;")
                                property string nSummary: parts[0] || ""
                                property string nBody:    parts[1] || ""
                                property string nApp:     parts[2] || ""
                                property string nImage:   parts[3] || ""
                                property bool   hasImage: nImage !== "" && nImage !== "null"
                                property string copyText: [nSummary, nBody].filter(s => s !== "").join("\n")
                                property color  tint:     root.appAccent(notifCard.nApp !== "" ? notifCard.nApp : "System")

                                width: parent.width
                                height: cardLayout.height + 24
                                radius: 12
                                color: cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.035)
                                border.color: cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1
                                clip: true
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }

                                MouseArea {
                                    id: cardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton // purely for hover state, clicks handled by children
                                }

                                // Per-app accent bar
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: 3
                                    color: notifCard.tint
                                }

                                Column {
                                    id: cardLayout
                                    anchors {
                                        top: parent.top; left: parent.left; right: parent.right
                                        margins: 12; leftMargin: 16
                                    }
                                    spacing: 8

                                    // App identity row: avatar + eyebrow name + summary
                                    RowLayout {
                                        width: parent.width
                                        spacing: 8

                                        Rectangle {
                                            width: 20; height: 20; radius: 6
                                            color: Qt.rgba(notifCard.tint.r, notifCard.tint.g, notifCard.tint.b, 0.22)
                                            border.color: Qt.rgba(notifCard.tint.r, notifCard.tint.g, notifCard.tint.b, 0.5)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: (notifCard.nApp !== "" ? notifCard.nApp.charAt(0) : "S").toUpperCase()
                                                color: notifCard.tint
                                                font.family: root.activeFont; font.pixelSize: 10; font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            text: (notifCard.nApp !== "" ? notifCard.nApp : "System").toUpperCase()
                                            color: notifCard.tint
                                            font.family: root.activeFont; font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.6
                                        }

                                        Text {
                                            text: notifCard.nSummary
                                            color: root.fgColor
                                            font.family: root.activeFont; font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Body Text
                                    Text {
                                        width: parent.width
                                        text: notifCard.nBody
                                        visible: notifCard.nBody !== ""
                                        color: Qt.rgba(1, 1, 1, 0.5)
                                        font.family: root.activeFont; font.pixelSize: 11
                                        lineHeight: 1.25
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }

                                    // Image Preview
                                    Rectangle {
                                        width: parent.width
                                        height: 140
                                        visible: notifCard.hasImage
                                        radius: 10
                                        color: Qt.rgba(0, 0, 0, 0.25)
                                        clip: true
                                        border.color: Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            source: notifCard.hasImage ? ("file://" + notifCard.nImage) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                        }
                                    }

                                    // Action Buttons Row
                                    Row {
                                        spacing: 8

                                        // Copy Button
                                        Rectangle {
                                            width: copyRow.implicitWidth + 22; height: 27; radius: 7
                                            color: copyHover.pressed ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.32)
                                                 : copyHover.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                                 : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: copyHover.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            Row {
                                                id: copyRow
                                                anchors.centerIn: parent; spacing: 5
                                                Text { text: "󰆏"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 11 }
                                                Text { text: "Copy"; color: root.fgColor; font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.Medium }
                                            }

                                            MouseArea {
                                                id: copyHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.copyContent(notifCard.nImage, notifCard.copyText)
                                            }
                                        }

                                        // Delete Button
                                        Rectangle {
                                            width: delRow.implicitWidth + 22; height: 27; radius: 7
                                            visible: notifCard.hasImage
                                            color: delHover.pressed ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.32)
                                                 : delHover.containsMouse ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.16)
                                                 : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: delHover.containsMouse ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            Row {
                                                id: delRow
                                                anchors.centerIn: parent; spacing: 5
                                                Text { text: "󰆴"; color: root.errorColor; font.family: root.activeFont; font.pixelSize: 11 }
                                                Text { text: "Delete"; color: root.errorColor; font.family: root.activeFont; font.pixelSize: 11; font.weight: Font.Medium }
                                            }

                                            MouseArea {
                                                id: delHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.deleteContent(notifCard.nImage)

                                                    let tempArr = root.notifEntries.slice()
                                                    tempArr.splice(index, 1)
                                                    root.notifEntries = tempArr
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { width: parent.width; height: 12 }
                }
            }
        }
    }
}