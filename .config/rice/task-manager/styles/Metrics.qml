pragma Singleton
import QtQuick

// Metrics.qml
// Central spacing/sizing/radius/font constants, so every component pulls
// from the same scale instead of hardcoding pixel values. Mirrors Windows 11's
// Fluent Design spacing rhythm (multiples of 4px) and rounded-corner language.
//
// Usage:
//   import "root:/styles" as Styles
//   radius: Styles.Metrics.radiusMedium
//   spacing: Styles.Metrics.spacingMd

QtObject {
    id: root

    // ---- Spacing scale (4px base grid) ----
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int spacingXxl: 32

    // ---- Corner radii (Fluent uses small consistent rounding, not iOS-style huge radii) ----
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12

    // ---- Window ----
    readonly property int windowWidth: 900
    readonly property int windowHeight: 600
    readonly property int windowMinWidth: 640
    readonly property int windowMinHeight: 420

    // ---- Title bar ----
    readonly property int titleBarHeight: 40
    readonly property int titleBarButtonSize: 46

    // ---- Sidebar ----
    readonly property int sidebarWidth: 180
    readonly property int sidebarItemHeight: 40

    // ---- Process list ----
    readonly property int processRowHeight: 36
    readonly property int processIconSize: 20
    readonly property int columnHeaderHeight: 32

    // ---- Performance tab cards ----
    readonly property int usageCardWidth: 200
    readonly property int usageCardHeight: 140
    readonly property int usageGraphHeight: 80

    // ---- Context menu ----
    readonly property int contextMenuWidth: 180
    readonly property int contextMenuItemHeight: 32

    // ---- Font sizes ----
    readonly property int fontSizeXs: 11
    readonly property int fontSizeSm: 12
    readonly property int fontSizeMd: 13
    readonly property int fontSizeLg: 16
    readonly property int fontSizeXl: 22

    // ---- Font family (fallback chain: put a Segoe-like font first if installed) ----
    readonly property string fontFamily: "Inter, Segoe UI, sans-serif"

    // ---- Animation durations (ms) ----
    readonly property int animFast: 100
    readonly property int animNormal: 180
    readonly property int animSlow: 300
}
