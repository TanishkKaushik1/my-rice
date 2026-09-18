import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    // Props passed in from bar.qml
    property bool  calendarOpen: false
    property color accentColor:  "#9fd49b"
    property color fgColor:      "#e0e4db"
    property string activeFont:  "Inter Nerd Font"

    PanelWindow {
        id: calWin
        required property var modelData
        screen: modelData
        anchors { top: true; right: true }
        margins { top: 56; right: 5 }
        implicitWidth:  calendarOpen ? 232 : 0
        implicitHeight: calendarOpen ? 262 : 0
        WlrLayershell.keyboardFocus: calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        property var  now:         new Date()
        property int  today:       now.getDate()
        property int  month:       now.getMonth()
        property int  year:        now.getFullYear()
        property int  firstDow:    new Date(year, month, 1).getDay()
        property int  daysInMonth: new Date(year, month + 1, 0).getDate()
        property int  totalCells:  firstDow + daysInMonth

        Rectangle {
            anchors.fill: parent
            visible: calendarOpen
            color: "#ee0d0d0d"
            border.color: Qt.rgba(1,1,1,0.1)
            radius: 14

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    text: Qt.formatDateTime(calWin.now, "MMMM  yyyy")
                    color: accentColor
                    font.family: activeFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignHCenter
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2
                    Repeater {
                        model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                        Text {
                            text: modelData
                            width: 28
                            color: "#555"
                            font.family: activeFont
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: 2
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: calWin.totalCells
                        Rectangle {
                            property int  dayNum:  index - calWin.firstDow + 1
                            property bool isDay:   index >= calWin.firstDow
                            property bool isToday: isDay && dayNum === calWin.today
                            width: 26; height: 22; radius: 11
                            color: isToday ? Qt.rgba(0.498, 0.784, 1, 0.22) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.isDay ? parent.dayNum : ""
                                color: parent.isToday ? accentColor
                                     : parent.isDay   ? "#999" : "transparent"
                                font.family: activeFont
                                font.pixelSize: 10
                                font.weight: parent.isToday ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }

                Text {
                    text: Qt.formatDateTime(calWin.now, "dddd, d MMMM")
                    color: "#555"
                    font.family: activeFont
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
