import QtQuick
import QtQuick.Layouts
import "root:/styles" as Styles
import "views" as Views

// TaskManager.qml
// Root layout for the whole task manager: TitleBar on top, Sidebar + active
// tab view below. This is the component shell.qml instantiates (inside a
// PanelWindow or floating niri window — see shell.qml notes).
//
// Usage (from shell.qml):
//   TaskManager {
//       anchors.fill: parent
//   }

Rectangle {
    id: root

    implicitWidth: Styles.Metrics.windowWidth
    implicitHeight: Styles.Metrics.windowHeight
    color: Styles.Theme.windowBackground
    radius: Styles.Metrics.radiusLarge

    property string currentTab: "processes" // "processes" | "performance" | "startup"

    // Emitted so shell.qml can decide what closing actually means
    // (destroy the window, hide a panel, etc.)
    signal closeRequested()
    signal minimizeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            onCloseRequested: root.closeRequested()
            onMinimizeRequested: root.minimizeRequested()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                selectedTab: root.currentTab
                onTabSelected: tab => root.currentTab = tab
            }

            // ---- Active tab content ----
            // Loader swaps the view instead of keeping all three alive at once,
            // so background polling in unused tabs' visuals doesn't waste cycles
            // (the underlying services still poll regardless, since those are
            // singletons — this only affects the view layer).
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: {
                    switch (root.currentTab) {
                        case "processes": return processesViewComponent
                        case "performance": return performanceViewComponent
                        case "startup": return startupViewComponent
                        case "startup": return startupViewComponent
                        case "storage": return storageViewComponent
                        default: return processesViewComponent
                    }
                }
            }
        }
    }

    Component { id: processesViewComponent; Views.ProcessesView {} }
    Component { id: performanceViewComponent; Views.PerformanceView {} }
    Component { id: startupViewComponent; Views.StartupView {} }
    Component { id: storageViewComponent; Views.StorageView {} }
}
