import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: healthPill

    property color pillBg:     "#99000000"
    property color fgColor:    "#e0e4db"
    property color accentColor:"#9fd49b"
    property color errorColor: "#ffb4ab"
    property string activeFont:"Inter Nerd Font"
    property int cpuVal: 0
    property int ramVal: 0
    property int tempVal: 0

    // ── System Metrics Data Fetching (sysfs / proc paths) ─────────────────
    property var _cpuProc: Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'"]
        stdout: SplitParser {
            onRead: data => {
                let val = Math.round(parseFloat(data.trim()))
                if (!isNaN(val)) healthPill.cpuVal = val
            }
        }
    }

    property var _ramProc: Process {
        id: ramProc
        command: ["sh", "-c", "free | awk '/Mem:/ {print int($3/$2 * 100)}'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data.trim())
                if (!isNaN(val)) healthPill.ramVal = val
            }
        }
    }

    property var _tempProc: Process {
        id: tempProc
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                let raw = parseInt(data.trim())
                if (!isNaN(raw)) healthPill.tempVal = Math.round(raw / 1000)
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = false; cpuProc.running = true
            ramProc.running = false; ramProc.running = true
            tempProc.running = false; tempProc.running = true
        }
    }

    Layout.preferredHeight: 32
    Layout.preferredWidth: healthRow.implicitWidth + 28
    Layout.alignment: Qt.AlignVCenter
    color: pillBg
    radius: 16
    border.color: Qt.rgba(1,1,1,0.06)

    Row {
        id: healthRow
        anchors.centerIn: parent
        spacing: 12

        Row {
            spacing: 5
            Text {
                text: "󰻠"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: cpuVal + "%"
                color: cpuVal > 80 ? errorColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 5
            Text {
                text: "󰍛"
                color: accentColor
                font.family: activeFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: ramVal + "%"
                color: ramVal > 85 ? errorColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(1,1,1,0.15)
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 5
            Text {
                text: "󰔏"
                color: tempVal > 80 ? errorColor : accentColor
                font.family: activeFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: tempVal + "°C"
                color: tempVal > 80 ? errorColor : fgColor
                font.family: activeFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}