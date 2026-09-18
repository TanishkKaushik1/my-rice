import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    // ── theme props ──────────────────────────────────────────────────────
    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property color errorColor:  "#ffb4ab"
    property string activeFont: "Inter Nerd Font"

    // ── data (owned by root, passed in) ──────────────────────────────────
    property var appsModel: []          // [{name, exec, icon}]
    property int currentIndex: 0        // "center" index into appsModel
    property int visibleHalf: 2         // shows visibleHalf*2+1 icons
    property real itemSize: 36
    property real spacingX: 48
    property real arcDip: 20
    property real addButtonSize: 24
    property real addButtonGap: 18      // gap between last app icon and "+" button
    property bool hovering: false

    // ── center-change slide animation state ────────────────────────────────
    property int _prevIndex: currentIndex
    property int _slideDir: 0     // -1 previous, +1 next, 0 idle
    property real _slideProgress: 0

    NumberAnimation {
        id: slideAnim
        target: root
        property: "_slideProgress"
        from: 1
        to: 0
        duration: 320
        easing.type: Easing.OutCubic
    }

    onCurrentIndexChanged: {
        let len = root.appsModel.length
        if (len > 0) {
            let delta = ((currentIndex - _prevIndex) % len + len) % len
            if (delta > len / 2) delta -= len
            root._slideDir = delta > 0 ? 1 : (delta < 0 ? -1 : 0)
        }
        _prevIndex = currentIndex
        slideAnim.restart()
    }

    // ── signals up to parent ─────────────────────────────────────────────
    signal scrollNext()
    signal scrollPrev()
    signal selectRequested(int index)
    signal launchRequested(var app)
    signal removeRequested(int index)
    signal requestOpenPicker()

    implicitWidth: itemSize + 2 * visibleHalf * spacingX + 2 * addButtonGap + 2 * addButtonSize + 20
    implicitHeight: 52

    function wrap(i) {
        let len = root.appsModel.length
        if (len === 0) return 0
        return ((i % len) + len) % len
    }

    function launchCenter() {
        if (root.appsModel.length === 0) return
        cleanAndLaunch(root.appsModel[root.wrap(root.currentIndex)])
    }

    function cleanAndLaunch(appObj) {
        if (!appObj || !appObj.exec) return
        
        let safeApp = Object.assign({}, appObj)
        
        // 1. Strip Freedesktop placeholders (%U, %f, %F, etc.)
        let cleaned = safeApp.exec.replace(/%[a-zA-Z]/g, "").trim()
        
        // 2. Detach process from Quickshell's Wayland environment
        if (!cleaned.startsWith("steam")) {
            safeApp.exec = "setsid -f " + cleaned
        } else {
            safeApp.exec = cleaned
        }
        
        root.launchRequested(safeApp)
    }

    HoverHandler {
        onHoveredChanged: {
            root.hovering = hovered
            if (hovered) arcFocus.forceActiveFocus()
        }
    }

    // Soft ambient glow behind arc
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.7
        height: 36
        radius: height / 2
        color: root.accentColor
        opacity: root.hovering ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    FocusScope {
        id: arcFocus
        anchors.fill: parent
        focus: true

        Keys.onLeftPressed:   root.scrollPrev()
        Keys.onRightPressed:  root.scrollNext()
        Keys.onReturnPressed: root.launchCenter()
        Keys.onEnterPressed:  root.launchCenter()

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real accum: 0
            onWheel: event => {
                accum += event.angleDelta.y !== 0 ? event.angleDelta.y : -event.pixelDelta.y
                let threshold = 50
                while (accum >= threshold)  { root.scrollPrev(); accum -= threshold }
                while (accum <= -threshold) { root.scrollNext(); accum += threshold }
            }
        }

        Repeater {
            model: root.visibleHalf * 2 + 1

            delegate: Item {
                id: slot
                property int offset: index - root.visibleHalf
                property int appIndex: root.appsModel.length > 0 ? root.wrap(root.currentIndex + offset) : -1
                property var app: appIndex >= 0 ? root.appsModel[appIndex] : null
                property bool isCenter: offset === 0
                property bool itemHovered: false
                property bool pressedState: false

                width: root.itemSize
                height: root.itemSize
                visible: app !== null

                property real normOffset: root.visibleHalf > 0 ? offset / root.visibleHalf : 0

                x: root.hovering
                       ? (parent.width / 2 - width / 2 + offset * root.spacingX)
                       : (parent.width / 2 - width / 2)
                y: 2 + root.arcDip * Math.cos(normOffset * 0.9)

                scale: (isCenter ? 1.0 : 1.0 - Math.abs(normOffset) * 0.18) * (itemHovered ? 1.06 : 1.0)
                transformOrigin: Item.Bottom
                opacity: app === null ? 0 : (root.hovering ? (isCenter ? 1.0 : 1.0 - Math.abs(normOffset) * 0.35) : 0)

                Behavior on x {
                    NumberAnimation {
                        duration: 280 + Math.abs(slot.offset) * 45
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 280 + Math.abs(slot.offset) * 45
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
                Behavior on scale {
                    NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + (isCenter ? 10 : 0)
                    height: parent.height
                    radius: 10
                    color: "transparent"
                    border.width: isCenter ? 1.5 : 0
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)
                    visible: isCenter
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 14
                    height: parent.height
                    radius: 10
                    color: root.accentColor
                    opacity: isCenter ? 0.10 : 0
                    visible: isCenter
                }

                Rectangle {
                    id: pill
                    anchors.fill: parent
                    radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.pillBg, slot.itemHovered ? 1.35 : 1.0) }
                        GradientStop { position: 1.0; color: root.pillBg }
                    }
                    border.width: isCenter ? 1 : (slot.itemHovered ? 1 : 0)
                    border.color: isCenter ? root.accentColor : Qt.rgba(1, 1, 1, 0.22)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Item {
                        id: content
                        anchors.fill: parent
                        x: root.hovering ? root._slideDir * root.spacingX * root._slideProgress : 0
                        opacity: 1 - Math.abs(root._slideDir) * root._slideProgress * 0.5
                        scale: slot.pressedState ? 0.86 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 1
                            height: parent.height * 0.45
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        IconImage {
                            id: iconImg
                            anchors.centerIn: parent
                            width: parent.width * 0.68
                            height: parent.height * 0.68
                            source: slot.app && slot.app.icon ? Quickshell.iconPath(slot.app.icon, "") : ""
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.68
                            height: parent.height * 0.68
                            radius: 6
                            visible: iconImg.status !== Image.Ready
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, isCenter ? 0.22 : 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: slot.app ? (slot.app.name.length > 0 ? slot.app.name.substring(0, 2).toUpperCase() : "?") : ""
                                color: root.fgColor
                                font.family: root.activeFont
                                font.pixelSize: 13
                                font.bold: isCenter
                            }
                        }

                        Rectangle {
                            visible: isCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4; height: 4; radius: 2
                            color: root.accentColor
                        }
                    }

                    Rectangle {
                        id: ripple
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height
                        radius: parent.radius
                        color: root.accentColor
                        opacity: 0
                        scale: 0.6
                        NumberAnimation {
                            id: rippleScaleAnim
                            target: ripple; property: "scale"
                            from: 0.6; to: 1.9; duration: 420; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            id: rippleOpacityAnim
                            target: ripple; property: "opacity"
                            from: 0.4; to: 0; duration: 420; easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hovering
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: slot.itemHovered = true
                        onExited:  slot.itemHovered = false
                        onPressed: slot.pressedState = true
                        onReleased: slot.pressedState = false
                        onCanceled: slot.pressedState = false
                        onClicked: mouse => {
                            rippleScaleAnim.restart()
                            rippleOpacityAnim.restart()
                            if (!slot.app) return
                            if (mouse.button === Qt.RightButton) {
                                root.removeRequested(slot.appIndex)
                            } else if (slot.isCenter) {
                                cleanAndLaunch(slot.app)
                            } else {
                                root.selectRequested(slot.appIndex)
                            }
                        }
                    }
                }
            }
        }

        // Add application launcher button
        Rectangle {
            id: addBtn
            width: root.addButtonSize; height: root.addButtonSize
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: parent.width / 2 + root.itemSize / 2 + root.visibleHalf * root.spacingX + root.addButtonGap
            anchors.verticalCenter: parent.verticalCenter
            color: addHover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18) : root.pillBg
            Behavior on color { ColorAnimation { duration: 150 } }
            border.width: 1
            border.color: root.accentColor
            scale: addHover.hovered ? 1.1 : (addPressed ? 0.85 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            property bool addPressed: false

            opacity: root.hovering ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: root.accentColor
                font.family: root.activeFont
                font.pixelSize: 15
                font.bold: true
                rotation: addHover.hovered ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            HoverHandler { id: addHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: addBtn.addPressed = true
                onReleased: addBtn.addPressed = false
                onCanceled: addBtn.addPressed = false
                onClicked: root.requestOpenPicker()
            }
        }
    }
}