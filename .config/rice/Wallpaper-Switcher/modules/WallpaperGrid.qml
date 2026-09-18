import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"

Item {
    id: root

    // ── Public ────────────────────────────────────────────────────────────
    property var    model:      null
    property string filterText: ""
    property bool   safeMode:   true

    signal applyRequested(string workshopId, string wallpaperPath, string previewPath)
    signal settingsRequested(string workshopId, string folderPath, string previewPath)

    // ── Filtered proxy ────────────────────────────────────────────────────
    property var filteredItems:  []
    property real _savedScrollY: -1
    property string activeBorderColor: "#ef4444" // Default fallback

    // ── Sync Border Color from Matugen ────────────────────────────────────
    Process {
        id: colorSyncProc
        command: ["bash", "-c", "grep '\"primary\"' \"$HOME/.config/rice/matugen/colors.json\" | cut -d '\"' -f 4"]
        
        stdout: SplitParser { 
            onRead: function(line) { 
                var cleanLine = line.trim()
                if (cleanLine !== "") root.activeBorderColor = cleanLine
            } 
        }
    }

    Component.onCompleted: {
        colorSyncProc.running = true
    }

    // Debounce timer — coalesces rapid countChanged signals during chunked
    // model loading into a single rebuild.
    Timer {
        id: filterDebounce
        interval: 60    // one frame at 60 fps
        repeat:   false
        onTriggered: root._doRebuildFilter()
    }

    function rebuildFilter() {
        filterDebounce.restart()
    }

    function _doRebuildFilter() {
        if (!model) { filteredItems = []; return }

        var ft      = filterText.toLowerCase()
        var visible = []

        for (var i = 0; i < model.count; i++) {
            var item   = model.get(i)
            var isNsfw = item.isNsfw !== undefined ? item.isNsfw : false
            var entry  = {
                workshopId:    item.workshopId,
                title:         item.title,
                wallpaperType: item.wallpaperType,
                previewPath:   item.previewPath,
                folderPath:    item.folderPath,
                isNsfw:        isNsfw
            }

            if (safeMode && isNsfw) continue

            if (ft === "" ||
                item.title.toLowerCase().indexOf(ft) !== -1 ||
                item.workshopId.indexOf(ft) !== -1) {
                visible.push(entry)
            }
        }

        filteredItems = visible
        
        // Restore the scroll position AFTER the grid receives the new array
        if (_savedScrollY !== -1) {
            var targetY = _savedScrollY
            _savedScrollY = -1
            Qt.callLater(function() {
                grid.contentY = targetY
            })
        }
    }

    onFilterTextChanged: rebuildFilter()
    onSafeModeChanged:   rebuildFilter()

    onModelChanged: {
        if (model) model.countChanged.connect(rebuildFilter)
        rebuildFilter()
    }

    // ── Delete ────────────────────────────────────────────────────────────
    property string _pendingDeleteId:   ""
    property string _pendingDeletePath: ""

    function requestDelete(workshopId, folderPath) {
        _pendingDeleteId   = workshopId
        _pendingDeletePath = folderPath
        
        // Fetch the freshest color from Matugen right before showing the dialog
        colorSyncProc.running = true 
        
        deleteDialog.open()
    }

    Process {
        id: deleteProc
        stdout: SplitParser { onRead: function(line) { console.log("rm:", line) } }
        stderr: SplitParser { onRead: function(line) { console.log("rm err:", line) } }
        onExited: function(code) {
            if (code !== 0) return
            
            // Save the scroll position before modifying the model
            root._savedScrollY = grid.contentY

            for (var i = 0; i < root.model.count; i++) {
                if (root.model.get(i).workshopId === root._pendingDeleteId) {
                    root.model.remove(i); break
                }
            }
            
            root._pendingDeleteId   = ""
            root._pendingDeletePath = ""
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent; spacing: 16
        visible: root.filteredItems.length === 0

        Text { 
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⬡"
            color: "#333333"
            font.pixelSize: 48 
        }
        Text { 
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterText !== "" ? "No results for \"" + root.filterText + "\""
                                         : "No wallpapers found"
            color: "#888888"
            font.pixelSize: 13
            font.family: "monospace" 
        }
        Text { 
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filterText === "" ? "Make sure Steam Workshop wallpapers are downloaded" : ""
            color: "#555555"
            font.pixelSize: 11
            font.family: "monospace" 
        }
    }

    // ── Main grid ─────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
        clip: true
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded; width: 4
            contentItem: Rectangle { radius: 2; color: "#666666" }
            background:  Rectangle { color: "transparent" }
        }

        GridView {
            id: grid
            width: parent.width
            cellWidth: 260; cellHeight: 220
            model: root.filteredItems.length
            currentIndex: -1
            cacheBuffer: grid.cellHeight * 2

            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight

                Loader {
                    anchors.fill: parent; anchors.margins: 10
                    asynchronous: true
                    sourceComponent: WallpaperCard {
                        workshopId:    root.filteredItems[index].workshopId
                        title:         root.filteredItems[index].title
                        wallpaperType: root.filteredItems[index].wallpaperType
                        previewPath:   root.filteredItems[index].previewPath
                        folderPath:    root.filteredItems[index].folderPath
                        
                        onApplyRequested:    function(wid, wpath, wp) { root.applyRequested(wid, wpath, wp) }
                        onSettingsRequested: function(wid, fpath, wp) { root.settingsRequested(wid, fpath, wp) }
                        onDeleteRequested:   function(wid, fpath)     { root.requestDelete(wid, fpath) }
                    }
                }
            }
        }
    }

   // ── Delete dialog ─────────────────────────────────────────────────────
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent; width: 340; modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside; z: 20
        
        background: Rectangle { 
            color: "#121215"  
            radius: 12
            border.color: root.activeBorderColor
            border.width: 1 
        }

        Column {
            width: parent.width; spacing: 16; padding: 16

            Text { 
                text: "Delete Wallpaper?"
                color: "#ffffff"
                font.pixelSize: 14; font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter 
            }
            Text { 
                width: parent.width - 16
                text: "This will permanently delete:\n" + root._pendingDeletePath
                color: "#a0a0a0"
                font.pixelSize: 11; font.family: "monospace"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12

                Rectangle {
                    width: 100; height: 34; radius: 6
                    color: cancelHov.containsMouse ? "#1a1a1a" : "transparent"
                    border.color: "#444444"; border.width: 1
                    
                    Text { 
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: "#ffffff"
                        font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold 
                    }
                    HoverHandler { id: cancelHov }
                    TapHandler { onTapped: deleteDialog.close() }
                }
                
                Rectangle {
                    width: 100; height: 34; radius: 6
                    color: confirmHov.containsMouse ? "#ef4444" : "#dc2626"
                    
                    Text { 
                        anchors.centerIn: parent
                        text: "DELETE"
                        color: "#ffffff"
                        font.pixelSize: 10; font.family: "monospace"; font.weight: Font.Bold 
                    }
                    HoverHandler { id: confirmHov }
                    TapHandler {
                        onTapped: {
                            deleteDialog.close()
                            if (root._pendingDeleteId !== "") {
                                Qt.openUrlExternally("steam://unsubscribe/" + root._pendingDeleteId)
                                
                                if (root._pendingDeletePath !== "") {
                                    deleteProc.command = ["bash", "-c", "rm -rf \"" + root._pendingDeletePath + "\""]
                                    deleteProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}