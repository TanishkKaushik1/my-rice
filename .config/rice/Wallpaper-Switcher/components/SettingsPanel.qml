import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: panel

    // ── Public ────────────────────────────────────────────────────────────
    property string targetWallpaperId:   ""
    property string targetWallpaperPath: ""
    property string targetWallpaperPreview: ""

    signal applyRequested(string workshopId, string wallpaperPath, string previewPath)

    // ── Dynamic Properties Parser ─────────────────────────────────────────
    ListModel {
        id: customPropsModel
    }

    property var _propReader: Process {
        id: propReader
        property string _buf: ""
        onStarted: _buf = ""
        stdout: SplitParser { onRead: function(line) { propReader._buf += line } }
        onExited: function(code) {
            customPropsModel.clear()
            if (code !== 0 || _buf === "") return
            try {
                var data = JSON.parse(_buf)
                if (data.general && data.general.properties) {
                    var props = data.general.properties
                    for (var key in props) {
                        var p = props[key]
                        customPropsModel.append({
                            propKey: key,
                            propText: p.text || key,
                            propType: p.type || "text",
                            defaultValue: String(p.value !== undefined ? p.value : "")
                        })
                    }
                }
            } catch(e) { console.log("Failed to parse project.json properties") }
        }
    }

    onTargetWallpaperPathChanged: {
        if (targetWallpaperPath !== "") {
            propReader.command = ["cat", targetWallpaperPath + "/project.json"]
            propReader.running = true
        } else {
            customPropsModel.clear()
        }
    }

    // ── Dock Body ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Flickable {
            id: flick
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footerArea.top
            contentHeight: col.implicitHeight + 20
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle { radius: 2; color: "#4a4a52" }
                background: Rectangle { color: "transparent" }
            }

            Column {
                id: col
                width: flick.width
                spacing: 0

                // ── Header ────────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 64

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: "#1e1e24"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: "⚙"
                            color: "#e0e0e4"
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: "LWE SETTINGS"
                                color: "#e0e0e4"
                                font.pixelSize: 11
                                font.family: "monospace"
                                font.letterSpacing: 2.5
                                font.weight: Font.Bold
                            }
                            Text {
                                text: panel.targetWallpaperId !== ""
                                    ? "ID: " + panel.targetWallpaperId
                                    : "no wallpaper selected"
                                color: "#7a7a80"
                                font.pixelSize: 9
                                font.family: "monospace"
                                font.letterSpacing: 0.5
                            }
                        }
                    }
                }

                // ── Section: Audio ─────────────────────────────────────────
                SettingsSectionLabel { label: "AUDIO" }

                SettingsRow {
                    label: "Volume"
                    sublabel: "--volume"
                    enabled: !LweSettingsService.mute

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        Slider {
                            id: volSlider
                            from: 0; to: 100
                            value: LweSettingsService.volume
                            enabled: !LweSettingsService.mute
                            width: 130; height: 24
                            stepSize: 1
                            anchors.verticalCenter: parent.verticalCenter
                            onValueChanged: LweSettingsService.volume = Math.round(value)

                            background: Rectangle {
                                x: volSlider.leftPadding
                                y: volSlider.height / 2 - height / 2
                                width: volSlider.availableWidth; height: 4; radius: 2
                                color: "#1a1a1e"
                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height; radius: 2
                                    color: volSlider.enabled ? "#e0e0e4" : "#35353c"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.height / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: volSlider.enabled ? (volSlider.pressed ? "#ffffff" : "#e0e0e4") : "#35353c"
                                border.color: volSlider.enabled ? "#ffffff" : "#4a4a52"
                                border.width: 1
                            }
                        }

                        Text {
                            text: Math.round(volSlider.value) + "%"
                            color: LweSettingsService.mute ? "#4a4a52" : "#a0a0a5"
                            font.pixelSize: 10; font.family: "monospace"
                            width: 34; horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                SettingsRow {
                    label: "Mute Output"
                    sublabel: "--silent"
                    ToggleSwitch {
                        checked: LweSettingsService.mute
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.mute = checked }
                    }
                }

                SettingsRow {
                    label: "Auto-Mute on App Audio"
                    sublabel: "--noautomute"
                    ToggleSwitch {
                        checked: LweSettingsService.automute
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.automute = checked }
                    }
                }

                // ── Section: Playlist ──────────────────────────────────────
                SettingsSectionLabel {
                    label: "PLAYLIST"
                    visible: LweSettingsService.hasPlaylist()
                }

                Item {
                    width: parent.width
                    height: 64
                    visible: LweSettingsService.hasPlaylist()

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: "#1e1e24"
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "Wallpaper"
                            color: "#7a7a80"; font.pixelSize: 11; font.family: "monospace"
                        }

                        Row {
                            spacing: 5

                            Rectangle {
                                width: badgeText.width + 10; height: 16; radius: 3
                                color: "#1a1a1e"
                                border.color: "#35353c"; border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: {
                                        var len = LweSettingsService.wallpapers ? LweSettingsService.wallpapers.length : 0;
                                        return (LweSettingsService.currentIndex + 1) + " / " + len;
                                    }
                                    color: "#e0e0e4"
                                    font.pixelSize: 9; font.family: "monospace"
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                text: {
                                    var wp = LweSettingsService.currentWallpaper
                                    if (!wp) return "—"
                                    var parts = wp.replace(/\/$/, "").split("/")
                                    return parts[parts.length - 1]
                                }
                                color: "#a0a0a5"
                                font.pixelSize: 9; font.family: "monospace"
                                elide: Text.ElideRight
                                width: 80
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            property bool isHovered: false
                            width: 36; height: 32; radius: 6
                            color: isHovered ? "#222228" : "transparent"
                            border.color: isHovered ? "#4a4a52" : "#2a2a30"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: parent.isHovered ? "#ffffff" : "#7a7a80"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.isHovered = true
                                onExited: parent.isHovered = false
                                onClicked: {
                                    LweSettingsService.previous()
                                    panel.applyRequested(
                                        panel.targetWallpaperId,
                                        LweSettingsService.currentWallpaper,
                                        panel.targetWallpaperPreview
                                    )
                                }
                            }
                        }

                        Rectangle {
                            property bool isHovered: false
                            width: 36; height: 32; radius: 6
                            color: isHovered ? "#222228" : "transparent"
                            border.color: isHovered ? "#4a4a52" : "#2a2a30"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: parent.isHovered ? "#ffffff" : "#7a7a80"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.isHovered = true
                                onExited: parent.isHovered = false
                                onClicked: {
                                    LweSettingsService.next()
                                    panel.applyRequested(
                                        panel.targetWallpaperId,
                                        LweSettingsService.currentWallpaper,
                                        panel.targetWallpaperPreview
                                    )
                                }
                            }
                        }
                    }
                }

                // ── Section: Display ───────────────────────────────────────
                SettingsSectionLabel { label: "DISPLAY" }

                SettingsRow {
                    label: "Scaling"
                    sublabel: "--scaling"
                    OptionPicker {
                        model: ["fill", "fit", "stretch", "center"]
                        currentValue: LweSettingsService.scaling
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onPicked: function(v) { LweSettingsService.scaling = v }
                    }
                }

                SettingsRow {
                    label: "FPS Cap"
                    sublabel: "--fps"

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        Slider {
                            id: fpsSlider
                            from: 10; to: 144
                            value: LweSettingsService.fps
                            width: 130; height: 24
                            stepSize: 1
                            anchors.verticalCenter: parent.verticalCenter
                            onValueChanged: LweSettingsService.fps = Math.round(value)

                            background: Rectangle {
                                x: fpsSlider.leftPadding
                                y: fpsSlider.height / 2 - height / 2
                                width: fpsSlider.availableWidth; height: 4; radius: 2
                                color: "#1a1a1e"
                                Rectangle {
                                    width: fpsSlider.visualPosition * parent.width
                                    height: parent.height; radius: 2
                                    color: "#e0e0e4"
                                }
                            }
                            handle: Rectangle {
                                x: fpsSlider.leftPadding + fpsSlider.visualPosition * (fpsSlider.availableWidth - width)
                                y: fpsSlider.height / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: fpsSlider.pressed ? "#ffffff" : "#e0e0e4"
                                border.color: "#ffffff"; border.width: 1
                            }
                        }

                        Text {
                            text: Math.round(fpsSlider.value)
                            color: "#a0a0a5"
                            font.pixelSize: 10; font.family: "monospace"
                            width: 34; horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                SettingsRow {
                    label: "Screen Root"
                    sublabel: "--screen-root"

                    Rectangle {
                        width: 110; height: 28; radius: 5
                        color: "transparent"
                        border.color: screenField.activeFocus ? "#e0e0e4" : "#2a2a30"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        TextInput {
                            id: screenField
                            anchors.fill: parent
                            anchors.margins: 8
                            text: LweSettingsService.screen
                            color: "#e0e0e4"
                            font.pixelSize: 11; font.family: "monospace"
                            selectionColor: "#4a4a52"
                            onEditingFinished: LweSettingsService.screen = text
                        }
                    }
                }

                // ── Section: Behavior & Performance ───────────────────────
                SettingsSectionLabel { label: "BEHAVIOR & INPUT" }

                SettingsRow {
                    label: "Disable Mouse Tracking"
                    sublabel: "--disable-mouse"
                    ToggleSwitch {
                        checked: LweSettingsService.disableMouse
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.disableMouse = checked }
                    }
                }

                SettingsRow {
                    label: "Disable Parallax"
                    sublabel: "--disable-parallax"
                    ToggleSwitch {
                        checked: LweSettingsService.disableParallax
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.disableParallax = checked }
                    }
                }

                SettingsRow {
                    label: "Pause on Fullscreen App"
                    sublabel: "--no-fullscreen-pause"
                    ToggleSwitch {
                        checked: LweSettingsService.pauseOnFullscreen
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.pauseOnFullscreen = checked }
                    }
                }

                SettingsRow {
                    label: "Pause on Focused App Only"
                    sublabel: "--fullscreen-pause-only-active"
                    enabled: LweSettingsService.pauseOnFullscreen
                    ToggleSwitch {
                        checked: LweSettingsService.pauseOnlyActive
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        onToggled: function(checked) { LweSettingsService.pauseOnlyActive = checked }
                    }
                }

                SettingsRow {
                    label: "Ignore App IDs"
                    sublabel: "--fullscreen-pause-ignore-appid"
                    enabled: LweSettingsService.pauseOnFullscreen

                    Rectangle {
                        width: 140; height: 28; radius: 5
                        color: "transparent"
                        border.color: ignoreField.activeFocus ? "#e0e0e4" : "#2a2a30"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right

                        TextInput {
                            id: ignoreField
                            anchors.fill: parent
                            anchors.margins: 6
                            text: LweSettingsService.ignoreAppIds
                            color: "#e0e0e4"
                            font.pixelSize: 10; font.family: "monospace"
                            selectionColor: "#4a4a52"
                            onEditingFinished: LweSettingsService.ignoreAppIds = text

                            Text {
                                anchors.fill: parent
                                text: "comma-sep IDs"
                                color: "#5a5a60"
                                font: parent.font
                                visible: parent.text === "" && !parent.activeFocus
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // ── Section: Dynamic Custom Properties ──────────────────────
                SettingsSectionLabel { 
                    label: "CUSTOM PROPERTIES" 
                    visible: customPropsModel.count > 0
                }

                Repeater {
                    model: customPropsModel
                    delegate: SettingsRow {
                        label: model.propText
                        sublabel: model.propKey

                        Loader {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // Load a ToggleSwitch for booleans, TextInput for everything else
                            sourceComponent: model.propType === "bool" ? boolComponent : textComponent
                            
                            property string pKey: model.propKey
                            property string savedVal: {
                                var saved = LweSettingsService.getCustomProperties(panel.targetWallpaperId)
                                return saved[model.propKey] !== undefined ? String(saved[model.propKey]) : model.defaultValue
                            }
                        }
                    }
                }
            }
        }

        // ── Fixed Footer ──────────────────────────────────────────────────
        Item {
            id: footerArea
            width: parent.width
            height: 110
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            Rectangle {
                anchors.top: parent.top
                width: parent.width - 40; height: 1
                color: "#1e1e24"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 12

                Rectangle {
                    id: applyBtn
                    property bool isHovered: false
                    width: parent.width; height: 40; radius: 8
                    color: isHovered ? "#ffffff" : "#e0e0e4"
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: "▶"
                            color: "#121215"; font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "SAVE & APPLY"
                            color: "#121215"; font.pixelSize: 11
                            font.family: "monospace"; font.letterSpacing: 1.8
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: applyBtn.isHovered = true
                        onExited: applyBtn.isHovered = false
                        onClicked: {
                            LweSettingsService.save()
                            var path = panel.targetWallpaperPath !== "" ? panel.targetWallpaperPath : LweSettingsService.currentWallpaper;
                            var id = panel.targetWallpaperId;
                            var preview = panel.targetWallpaperPreview;
                            if (path !== "") {
                                panel.applyRequested(id, path, preview)
                            }
                        }
                    }
                }

                Rectangle {
                    property bool isHovered: false
                    width: parent.width; height: 34; radius: 8
                    color: isHovered ? "#222228" : "transparent"
                    border.color: isHovered ? "#4a4a52" : "#2a2a30"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        text: "SAVE ONLY"
                        color: parent.isHovered ? "#ffffff" : "#a0a0a5"
                        font.pixelSize: 10; font.family: "monospace"
                        font.letterSpacing: 1.5; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.isHovered = true
                        onExited: parent.isHovered = false
                        onClicked: LweSettingsService.save()
                    }
                }
            }
        }

        // ── Sub-components ────────────────────────────────────────────────

       Component {
            id: boolComponent
            ToggleSwitch {
                // Safely catch any old "true" strings, but check for "1" normally
                checked: parent.savedVal === "true" || parent.savedVal === "1" || parent.savedVal === 1
                
                onToggled: function(c) {
                    // Send strictly 1 or 0 to match linux-wallpaperengine's C++ parser
                    LweSettingsService.setCustomProperty(panel.targetWallpaperId, parent.pKey, c ? 1 : 0)
                }
            }
        }

        Component {
            id: textComponent
            Rectangle {
                width: 140; height: 28; radius: 5
                color: "transparent"
                border.color: propField.activeFocus ? "#e0e0e4" : "#2a2a30"
                border.width: 1
                
                TextInput {
                    id: propField
                    anchors.fill: parent
                    anchors.margins: 6
                    text: parent.parent.savedVal
                    color: "#e0e0e4"
                    font.pixelSize: 10; font.family: "monospace"
                    selectionColor: "#4a4a52"
                    onEditingFinished: LweSettingsService.setCustomProperty(panel.targetWallpaperId, parent.parent.pKey, text)
                }
            }
        }

        component SettingsSectionLabel: Item {
            property string label: ""
            width: parent.width
            height: 38

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: "#1e1e24"
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 3; height: 10; radius: 1
                    color: "#e0e0e4"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: label
                    color: "#e0e0e4"
                    font.pixelSize: 9; font.family: "monospace"
                    font.letterSpacing: 2.5; font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

       component SettingsRow: Item {
            property string label: ""
            property string sublabel: ""
            default property alias content: controlSlot.data

            width: parent.width; height: 54

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: "#1e1e24"
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: controlSlot.left      // Lock the right edge to the control box
                anchors.rightMargin: 16              // Add a small gap before the control box
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width              // Force text to respect column width
                    text: label
                    color: parent.parent.enabled ? "#e0e0e4" : "#5a5a60"
                    font.pixelSize: 11; font.family: "monospace"
                    elide: Text.ElideRight           // Add "..." if text is too long
                    clip: true
                }
                Text {
                    width: parent.width              // Force text to respect column width
                    text: sublabel
                    color: "#5a5a60"; font.pixelSize: 9; font.family: "monospace"
                    font.letterSpacing: 0.3
                    elide: Text.ElideRight           // Add "..." if text is too long
                    clip: true
                }
            }
            Item {
                id: controlSlot
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 170
            }
        }

        component ToggleSwitch: Item {
            property bool checked: false
            signal toggled(bool checked)

            width: 36; height: 18

            Rectangle {
                anchors.fill: parent; radius: 9
                color: parent.checked ? "#4a4a52" : "#1a1a1e"
                border.color: parent.checked ? "#6a6a72" : "#2a2a30"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 14; height: 14; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.parent.checked ? parent.width - width - 2 : 1
                    color: parent.parent.checked ? "#e0e0e4" : "#5a5a60"
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    parent.checked = !parent.checked
                    parent.toggled(parent.checked)
                }
            }
        }

        component OptionPicker: Item {
            property var    model:        []
            property string currentValue: ""
            signal picked(string value)

            width: row.implicitWidth; height: 26

            Row {
                id: row
                spacing: 4

                Repeater {
                    model: parent.parent.model
                    delegate: Rectangle {
                        property bool active: modelData === currentValue
                        property bool isHovered: false
                        height: 24
                        width: optText.width + 16
                        radius: 6
                        color: active ? "#35353c" : (isHovered ? "#222228" : "transparent")
                        border.color: active ? "#8a8a8e" : (isHovered ? "#4a4a52" : "#2a2a30")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: optText
                            anchors.centerIn: parent
                            text: modelData
                            color: active ? "#ffffff" : (parent.isHovered ? "#e0e0e4" : "#7a7a80")
                            font.pixelSize: 10; font.family: "monospace"
                            font.letterSpacing: 0.5
                            font.weight: active ? Font.Bold : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.isHovered = true
                            onExited: parent.isHovered = false
                            onClicked: picked(modelData)
                        }
                    }
                }
            }
        }
    }
}