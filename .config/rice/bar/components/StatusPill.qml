import QtQuick
import QtQuick.Layouts

// ── RIGHT STATUS PILL ────────────────────────────────────────────────────────
// Displays Clock, Network (Eth/WiFi/BT), Notifications, Battery, and Power button.

Rectangle {
    id: statusPill

    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property color errorColor:  "#ffb4ab"
    property color btColor:     "#a1ced5"
    property string activeFont: "Inter Nerd Font"

    property string ethVal:     ""
    property string wifiVal:    ""
    property string btVal:      ""
    property string battVal:    ""
    property string battStatus: ""
    property string clockStr:   ""
    property bool calendarOpen: false
    property bool notifPanelOpen: false

    signal bellClicked()
    signal ethClicked()
    signal wifiClicked()
    signal btClicked()
    signal clockClicked()
    signal powerClicked()

    Layout.preferredHeight: 32
    Layout.preferredWidth: rightRow.implicitWidth + 26
    Layout.alignment: Qt.AlignVCenter
    color: pillBg
    radius: 16
    border.color: Qt.rgba(1, 1, 1, 0.06)

    Row {
        id: rightRow
        anchors.centerIn: parent
        spacing: 13

        // ── CLOCK ────────────────────────────────────────────
        Item {
            height: 22
            width: clockLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: clockLabel
                text: statusPill.clockStr
                color: statusPill.calendarOpen ? statusPill.accentColor : statusPill.fgColor
                font.family: statusPill.activeFont
                font.pixelSize: 12
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: statusPill.clockClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── ETHERNET ─────────────────────────────────────────
        Item {
            visible: statusPill.ethVal !== ""
            height: 22
            width: ethLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: ethLabel
                text: "󰈀"
                color: statusPill.fgColor
                font.family: statusPill.activeFont
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: statusPill.ethClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            visible: statusPill.ethVal !== ""
            width: 1; height: 14
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

       

        Rectangle {
            visible: statusPill.btVal !== ""
            width: 1; height: 14
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── NOTIFICATION / BELL ──────────────────────────────
        Item {
            height: 22
            width: bellLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: bellLabel
                text: "󰂚"
                color: statusPill.notifPanelOpen ? statusPill.accentColor : Qt.rgba(1, 1, 1, 0.55)
                font.family: statusPill.activeFont
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            TapHandler { onTapped: statusPill.bellClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── BATTERY ──────────────────────────────────────────
        Item {
            visible: statusPill.battVal !== ""
            height: 22
            width: battLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: battLabel
                text: {
                    let stat = statusPill.battStatus.trim().toLowerCase()
                    let icon = stat === "charging" ? "󰂄" : stat === "full" || stat === "not charging" ? "󰚥" : "󰁹"
                    return icon + "  " + statusPill.battVal + "%"
                }
                color: statusPill.battStatus.trim().toLowerCase() === "charging" ? statusPill.accentColor : statusPill.fgColor
                font.family: statusPill.activeFont
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            visible: statusPill.battVal !== ""
            width: 1; height: 14
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── POWER BUTTON ─────────────────────────────────────
        Item {
            height: 22
            width: powerLabel.implicitWidth
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: powerLabel
                text: "󰕮"
                color: statusPill.errorColor
                font.family: statusPill.activeFont
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            TapHandler { onTapped: statusPill.powerClicked() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}