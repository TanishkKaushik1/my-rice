pragma Singleton
import QtQuick
import "root:/services" as Services

// Theme.qml
// Semantic wrapper around ColorService. Components should bind to Theme.xxx
// (never raw hex, never ColorService directly) so that:
//   1. All color meaning is named for what it's USED for, not what it IS
//   2. If matugen's role names ever change, only this file needs updating
//
// Usage:
//   import "root:/styles" as Styles
//   color: Styles.Theme.windowBackground

QtObject {
    id: root

    // ---- Base surfaces ----
    readonly property color windowBackground: Services.ColorService.surface
    readonly property color cardBackground: Services.ColorService.surfaceContainer
    readonly property color sidebarBackground: Services.ColorService.surface
    readonly property color rowHover: Qt.lighter(Services.ColorService.surfaceContainer, 1.15)
    readonly property color rowSelected: Services.ColorService.primaryContainer

    // ---- Text ----
    readonly property color textPrimary: Services.ColorService.onSurfaceColor
    readonly property color textSecondary: Qt.rgba(Services.ColorService.onSurfaceColor.r,
                                                     Services.ColorService.onSurfaceColor.g,
                                                     Services.ColorService.onSurfaceColor.b, 0.65)
    readonly property color textDisabled: Qt.rgba(Services.ColorService.onSurfaceColor.r,
                                                    Services.ColorService.onSurfaceColor.g,
                                                    Services.ColorService.onSurfaceColor.b, 0.4)

    // ---- Accents / graphs ----
    readonly property color cpuGraphColor: Services.ColorService.primary
    readonly property color cpuGraphFill: Qt.rgba(Services.ColorService.primary.r,
                                                    Services.ColorService.primary.g,
                                                    Services.ColorService.primary.b, 0.2)

    readonly property color ramGraphColor: Services.ColorService.secondary
    readonly property color ramGraphFill: Qt.rgba(Services.ColorService.secondary.r,
                                                    Services.ColorService.secondary.g,
                                                    Services.ColorService.secondary.b, 0.2)

    readonly property color diskGraphColor: Services.ColorService.tertiary
    readonly property color diskGraphFill: Qt.rgba(Services.ColorService.tertiary.r,
                                                     Services.ColorService.tertiary.g,
                                                     Services.ColorService.tertiary.b, 0.2)

    // ---- Interactive elements ----
    readonly property color tabActiveIndicator: Services.ColorService.primary
    readonly property color buttonPrimary: Services.ColorService.primary
    readonly property color buttonPrimaryText: Services.ColorService.surface

    // ---- Danger / End Task ----
    readonly property color danger: Services.ColorService.error
    readonly property color dangerHover: Qt.darker(Services.ColorService.error, 1.15)

    // ---- Borders / dividers ----
    readonly property color divider: Qt.rgba(Services.ColorService.onSurfaceColor.r,
                                              Services.ColorService.onSurfaceColor.g,
                                              Services.ColorService.onSurfaceColor.b, 0.08)

    // ---- Context menu (right-click popup) ----
    readonly property color contextMenuBackground: Qt.lighter(Services.ColorService.surfaceContainer, 1.1)
    readonly property color contextMenuHover: Services.ColorService.primaryContainer

    // ---- Usage warning thresholds (Win11-style: green/yellow/red based on load) ----
    function usageColor(percent) {
        if (percent >= 85) return Services.ColorService.error
        if (percent >= 60) return Services.ColorService.tertiary
        return Services.ColorService.primary
    }
}
