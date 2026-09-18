import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
property string workshopRoot:
    Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960"
    readonly property string _scriptDir: {
        var u = Qt.resolvedUrl("../workshop_search.py").toString()
        return u.replace("file://", "").replace(/\/workshop_search\.py$/, "")
    }

    property var    results:     []
    property bool   loading:     false
    property string statusMsg:   ""
    property int    currentPage: 1
    property string lastQuery:   ""
    property string resFilter:   ""          
    property string sortBy:      "popular" // Changed default from relevance to popular
    property bool   allowNsfw:   false       

    // ── Search process ─────────────────────────────────────────────────────
    property var _searchProc: Process {
        id: searchProc
        property string _buf: ""
        onStarted: _buf = ""
        stdout: SplitParser { onRead: function(l) { searchProc._buf += l } }
        stderr: SplitParser { onRead: function(l) { searchProc._buf += l } }
        onExited: function(code) {
            root.loading = false
            if (code !== 0 || searchProc._buf.trim() === "") {
                root.statusMsg = "Search failed — check internet connection"
                return
            }
            try {
                var arr = JSON.parse(searchProc._buf.trim())
                if (arr.error) { root.statusMsg = "API error: " + arr.error; return }
                var mapped = arr.map(function(r) {
                    return {
                        workshopId:    r.id            || "",
                        title:         r.title          || "",
                        previewUrl:    r.preview_url    || "",
                        author:        r.author        || "",
                        subscriptions: r.subscriptions  || 0,
                        resolution:    r.resolution     || "",
                        wallpaperType: r.type           || "",
                        url:           r.url            || ""
                    }
                })
                root.results = mapped
                root.statusMsg = mapped.length > 0 ? mapped.length + " results" : "No results found"
            } catch(e) {
                root.statusMsg = "Parse error: " + e
            }
        }
    }

    // ── Functions ──────────────────────────────────────────────────────────
    function doSearch(query, page) {
        // Removed the query.trim() === "" check so it can fetch default top wallpapers
        if (loading) return 
        loading    = true
        lastQuery  = query
        currentPage = page
        statusMsg  = "Searching…"
        results    = []
        
        var args = ["python3", root._scriptDir + "/workshop_search.py", query, String(page), root.resFilter, root.sortBy, root.allowNsfw ? "true" : "false"]
        
        searchProc.command = args
        searchProc.running = true
    }

    function downloadWallpaper(wid) {
        if (wid === "") return
        Qt.openUrlExternally("steam://url/CommunityFilePage/" + wid)
        root.statusMsg = "Steam opened → Subscribe → Refresh Library"
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // ── Search bar row ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 8
                color: "#16161a" 
                border.color: wsInput.activeFocus ? "#5a5a60" : "#2a2a30"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "⌕"
                        color: wsInput.activeFocus ? "#e0e0e4" : "#5a5a60"
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: wsInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: "#e0e0e4"
                        font.pixelSize: 13
                        font.family: "monospace"
                        selectionColor: "#4a4a52"
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: "Search Workshop… anime, lofi, cyberpunk…"
                            color: "#5a5a60"
                            font: parent.font
                            visible: parent.text === "" && !parent.activeFocus
                            verticalAlignment: Text.AlignVCenter
                        }

                        Keys.onReturnPressed: root.doSearch(text, 1)
                        Keys.onEnterPressed:  root.doSearch(text, 1)
                    }

                    Rectangle {
                        width: 60; height: 32; radius: 6
                        color: goBtnH.containsMouse ? "#4a4a52" : "#35353c"
                        border.color: goBtnH.containsMouse ? "#6a6a72" : "#4a4a52"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.loading ? "…" : "GO"
                            color: "#e0e0e4"
                            font.pixelSize: 11
                            font.family: "monospace"
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                        HoverHandler { id: goBtnH }
                        TapHandler   { onTapped: root.doSearch(wsInput.text, 1) }
                    }
                }
            }
        }

        // ── Quick filter chips ─────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: ["anime", "lofi", "nature", "cyberpunk", "abstract", "genshin", "minimal", "city", "space"]
                delegate: Rectangle {
                    height: 26; width: chipLbl.width + 20; radius: 13
                    color: chipH.containsMouse ? "#35353c" : "#1a1a1e"
                    border.color: chipH.containsMouse ? "#5a5a60" : "#2a2a30"
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text {
                        id: chipLbl; anchors.centerIn: parent; text: modelData
                        color: chipH.containsMouse ? "#e0e0e4" : "#8a8a8e"
                        font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 0.8
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    HoverHandler { id: chipH }
                    TapHandler { onTapped: { wsInput.text = modelData; root.doSearch(modelData, 1) } }
                }
            }
        }

        // ── Filters Row (RES + SORT + SAFE MODE) ───────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            // -- Resolution filter --
            Row {
                spacing: 8
                Text {
                    text: "RES"
                    color: "#5a5a60"
                    font.pixelSize: 9
                    font.family: "monospace"
                    font.letterSpacing: 1.5
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: ["", "4K", "1080p", "1440p", "ultrawide"]
                    delegate: Rectangle {
                        height: 24; width: resLbl.width + 16; radius: 12
                        color: root.resFilter === modelData
                               ? "#35353c"
                               : (resH.containsMouse ? "#2a2a30" : "#1a1a1e")
                        border.color: root.resFilter === modelData ? "#8a8a8e"
                                      : (resH.containsMouse ? "#4a4a52" : "#2a2a30")
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        Text {
                            id: resLbl; anchors.centerIn: parent
                            text: modelData === "" ? "ALL" : modelData
                            color: root.resFilter === modelData ? "#ffffff"
                                   : (resH.containsMouse ? "#e0e0e4" : "#7a7a80")
                            font.pixelSize: 9; font.family: "monospace"; font.letterSpacing: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        HoverHandler { id: resH }
                        TapHandler {
                            onTapped: {
                                root.resFilter = modelData
                                if (root.lastQuery !== "" || root.results.length > 0) root.doSearch(root.lastQuery, 1)
                            }
                        }
                    }
                }
            }

            // -- Sort filter --
            Row {
                spacing: 8
                Text {
                    text: "SORT"
                    color: "#5a5a60"
                    font.pixelSize: 9
                    font.family: "monospace"
                    font.letterSpacing: 1.5
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: [
                        { label: "RELEVANCE", val: "relevance" },
                        { label: "POPULAR", val: "popular" },
                        { label: "TRENDING", val: "trend" },
                        { label: "RECENT", val: "recent" }
                    ]
                    delegate: Rectangle {
                        height: 24; width: sortLbl.width + 16; radius: 12
                        color: root.sortBy === modelData.val
                               ? "#35353c"
                               : (sortH.containsMouse ? "#2a2a30" : "#1a1a1e")
                        border.color: root.sortBy === modelData.val ? "#8a8a8e"
                                      : (sortH.containsMouse ? "#4a4a52" : "#2a2a30")
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        Text {
                            id: sortLbl; anchors.centerIn: parent
                            text: modelData.label
                            color: root.sortBy === modelData.val ? "#ffffff"
                                   : (sortH.containsMouse ? "#e0e0e4" : "#7a7a80")
                            font.pixelSize: 9; font.family: "monospace"; font.letterSpacing: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        HoverHandler { id: sortH }
                        TapHandler {
                            onTapped: {
                                root.sortBy = modelData.val
                                if (root.lastQuery !== "" || root.results.length > 0) root.doSearch(root.lastQuery, 1)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

           
        }

        // ── Status row ─────────────────────────────────────────────────────
        Row {
            spacing: 8
            visible: root.statusMsg !== "" || root.loading

            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.loading ? "#a0a0a5" : "#e0e0e4"
                SequentialAnimation on opacity {
                    running: root.loading; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
            Text {
                text: root.statusMsg; color: "#8a8a8e"
                font.pixelSize: 11; font.family: "monospace"; font.letterSpacing: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Results grid ───────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: root.results.length === 0 && !root.loading
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⬡"; color: "#2a2a30"; font.pixelSize: 56 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No wallpapers found"; color: "#7a7a80"; font.pixelSize: 13; font.family: "monospace" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Try adjusting your search or filters"; color: "#5a5a60"; font.pixelSize: 11; font.family: "monospace" }
            }

            GridView {
                id: resultsGrid
                anchors.fill: parent
                anchors.rightMargin: 8
                cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / 210)))
                cellHeight: 220
                model: root.results.length
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    contentItem: Rectangle { radius: 2; color: "#5a5a60" }
                    background: Rectangle { color: "transparent" }
                }

                delegate: Item {
                    id: cardDelegate
                    width:  resultsGrid.cellWidth
                    height: resultsGrid.cellHeight
                    readonly property var wdata: root.results[index] || {}

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 10
                        color: cardH.containsMouse ? "#1e1e24" : "#121215"
                        border.color: cardH.containsMouse ? "#4a4a52" : "#2a2a30"
                        border.width: 1
                        clip: true
                        Behavior on color        { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        HoverHandler { id: cardH }

                        // ── Thumbnail ──────────────────────────────────────
                        Rectangle {
                            id: imgArea
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height - 64
                            color: "#0a0a0c"
                            radius: 8
                            clip: true

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                source: cardDelegate.wdata.previewUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                cache: false
                                opacity: cardH.containsMouse ? 0.4 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "◇"; color: "#1a1a1e"; font.pixelSize: 28
                                visible: thumbImg.status !== Image.Ready
                            }

                            // Resolution badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 6
                                width: resBadge.width + 12; height: 20; radius: 4
                                color: "#1a1a1ecc"; border.color: "#35353c"; border.width: 1
                                visible: cardDelegate.wdata.resolution !== ""
                                Text {
                                    id: resBadge
                                    anchors.centerIn: parent
                                    text: cardDelegate.wdata.resolution
                                    color: "#e0e0e4"
                                    font.pixelSize: 8; font.letterSpacing: 1; font.family: "monospace"; font.weight: Font.Bold
                                }
                            }

                            // ── GET IN STEAM / SUBSCRIBE button ─────────────
                            Rectangle {
                                id: dlBtn
                                anchors.centerIn: parent
                                width: 140; height: 38
                                radius: 7
                                color: dlMouse.containsMouse ? "#e0e0e4" : "#a0a0a5"
                                opacity: cardH.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                Behavior on color   { ColorAnimation  { duration: 120 } }
                                z: 10

                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    Text { text: "↗"; color: "#121215"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "SUBSCRIBE"; color: "#121215"; font.pixelSize: 10; font.letterSpacing: 1.2; font.family: "monospace"; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: dlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.downloadWallpaper(cardDelegate.wdata.workshopId)
                                }
                            }
                        }

                        // ── Info strip ─────────────────────────────────────
                        Item {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 64
                            anchors.leftMargin: 10; anchors.rightMargin: 10

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; spacing: 4

                                Text {
                                    width: parent.width
                                    text: cardDelegate.wdata.title || ""
                                    color: cardH.containsMouse ? "#ffffff" : "#e0e0e4"
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Row {
                                    spacing: 8
                                    Text {
                                        text: "★ " + ((cardDelegate.wdata.subscriptions||0) > 999
                                            ? Math.floor((cardDelegate.wdata.subscriptions||0)/1000)+"k"
                                            : (cardDelegate.wdata.subscriptions||0))
                                        color: "#a0a0a5"; font.pixelSize: 9; font.family: "monospace"
                                    }
                                    Text {
                                        text: cardDelegate.wdata.author || ""
                                        color: "#7a7a80"; font.pixelSize: 9; font.family: "monospace"
                                        elide: Text.ElideRight; width: 80
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Pagination ─────────────────────────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            visible: root.results.length > 0 || root.currentPage > 1

            Rectangle {
                width: 80; height: 30; radius: 6
                color: prevH.containsMouse ? "#35353c" : "#1a1a1e"
                border.color: root.currentPage > 1 ? "#3a3a40" : "#1a1a1e"
                border.width: 1; opacity: root.currentPage > 1 ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "← PREV"; color: "#a0a0a5"; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1; font.weight: Font.Bold }
                HoverHandler { id: prevH }
                TapHandler { onTapped: if (root.currentPage > 1) root.doSearch(root.lastQuery, root.currentPage - 1) }
            }

            // ── Jump to Page Input ──
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "PAGE"
                    color: "#7a7a80"
                    font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1.5; font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 44; height: 26; radius: 6
                    color: pageInput.activeFocus ? "#2a2a30" : "#1a1a1e"
                    border.color: pageInput.activeFocus ? "#e0e0e4" : "#3a3a40"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: pageInput
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#e0e0e4"
                        font.pixelSize: 11; font.family: "monospace"
                        selectionColor: "#4a4a52"
                        selectedTextColor: "#ffffff"
                        selectByMouse: true
                        validator: IntValidator { bottom: 1; top: 9999 } 
                        
                        Component.onCompleted: text = root.currentPage.toString()

                        Connections {
                            target: root
                            function onCurrentPageChanged() {
                                pageInput.text = root.currentPage.toString()
                            }
                        }

                        onAccepted: {
                            var p = parseInt(text)
                            if (!isNaN(p) && p > 0 && p !== root.currentPage) {
                                root.doSearch(root.lastQuery, p)
                            } else {
                                text = root.currentPage.toString() 
                            }
                            focus = false
                        }
                    }
                }
            }

            Rectangle {
                width: 80; height: 30; radius: 6
                color: nextH.containsMouse ? "#35353c" : "#1a1a1e"
                border.color: "#3a3a40"; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.centerIn: parent; text: "NEXT →"; color: "#a0a0a5"; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1; font.weight: Font.Bold }
                HoverHandler { id: nextH }
                TapHandler { onTapped: if (root.results.length > 0) root.doSearch(root.lastQuery, root.currentPage + 1) }
            }
        }
    }
    
    // Auto-fetch top popular wallpapers when the component loads
    Component.onCompleted: {
        root.doSearch("", 1)
    }
}