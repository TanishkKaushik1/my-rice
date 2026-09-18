import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

ShellRoot {
    id: root
    property var visualizerData: new Array(32).fill(0)

    // ── MATUGEN COLORS ──────────────────────────────────────────────────────
    property color pillBg:      "#99000000"
    property color fgColor:     "#e0e4db"
    property color accentColor: "#9fd49b"
    property color errorColor:  "#ffb4ab"
    property color btColor:     "#a1ced5"

    property string activeFont: "Inter Nerd Font"
    property bool   calendarOpen: false

    property string musicTitle:  ""
    property string musicArtist: ""
    property string musicPlayer: ""
    property bool   isPlaying:   false
    property real musicPosition: 0
    property real musicLength: 1
    property real sysVolume: 0.5
    property bool sysMuted: false

    property int    cpuVal:     0
    property int    ramVal:     0
    property int    tempVal:    0 
    property string wifiVal:    ""
    property string ethVal:     ""
    property string btVal:      ""
    property string battVal: ""
    property string battStatus: ""
    property string clockStr: Qt.formatDateTime(new Date(), "HH:mm")
    property bool powerMenuOpen: false
    property bool notifPanelOpen: false
    property bool quickLauncherPickerOpen: false

    // ── QUICK LAUNCHER STATE ─────────────────────────────────────────────────
    // Lives here (not inside the QuickLauncher component) because that
    // component is instantiated once per screen inside the bar's `Variants`
    // delegate, and QML ids declared inside a repeated delegate aren't
    // reliably reachable from the top-level QuickLauncherPicker popup. Keeping
    // it all at root also means every monitor shares one launcher/state.
    property string quickLaunchConfigPath: "/home/tanishk/.config/rice/quicklaunch.json"
    property var    quickLaunchApps: []       // [{name, exec, icon}]
    property int    quickLaunchIndex: 0
    property var    quickLaunchInstalled: []  // scanned installed apps, for the picker

    function quickLaunchWrap(i) {
        let len = root.quickLaunchApps.length
        if (len === 0) return 0
        return ((i % len) + len) % len
    }
    function quickLaunchScrollNext() { if (root.quickLaunchApps.length > 0) root.quickLaunchIndex = root.quickLaunchWrap(root.quickLaunchIndex + 1) }
    function quickLaunchScrollPrev() { if (root.quickLaunchApps.length > 0) root.quickLaunchIndex = root.quickLaunchWrap(root.quickLaunchIndex - 1) }

    function quickLaunchSave() {
        quickLaunchSaveProc.pendingJson = JSON.stringify(root.quickLaunchApps)
        quickLaunchSaveProc.running = true
    }
    function quickLaunchAddApp(app) {
        let list = root.quickLaunchApps.slice()
        list.push({ name: app.name, exec: app.exec, icon: app.icon })
        root.quickLaunchApps = list
        root.quickLaunchSave()
    }
    function quickLaunchRemoveApp(idx) {
        let list = root.quickLaunchApps.slice()
        list.splice(idx, 1)
        root.quickLaunchApps = list
        if (root.quickLaunchIndex >= list.length) root.quickLaunchIndex = 0
        root.quickLaunchSave()
    }
    function quickLaunchLaunch(app) {
        quickLaunchLaunchProc.cmd = app.exec
        quickLaunchLaunchProc.running = true
    }
    function quickLaunchRefreshInstalled() {
        quickLaunchScanProc.buffer = []
        quickLaunchScanProc.running = true
    }

    // load saved quick-launch apps from disk
    Process {
        id: quickLaunchLoadProc
        command: ["sh", "-c", "cat '" + root.quickLaunchConfigPath + "' 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (Array.isArray(parsed)) root.quickLaunchApps = parsed
                } catch (e) {
                    console.log("QuickLauncher: parse error", e)
                    root.quickLaunchApps = []
                }
            }
        }
    }
    Component.onCompleted: quickLaunchLoadProc.running = true

    // save quick-launch apps to disk — JSON passed as an argv element (not
    // through shell string interpolation) so we never have to worry about
    // escaping quotes/$/backticks inside app names or exec strings
    Process {
        id: quickLaunchSaveProc
        property string pendingJson: "[]"
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"",
                  "_", pendingJson, root.quickLaunchConfigPath]
        running: false
    }

    // scan installed .desktop files for the "add app" picker — mirrors the
    // rules in your app-launcher's desktop.rs scan(): same three directories
    // in the same priority order (system → local-system → user), skips
    // Type!=Application / NoDisplay=true / Hidden=true / Terminal=true, and
    // later entries (user ~/.local) override earlier same-named ones
    Process {
        id: quickLaunchScanProc
        command: ["sh", "-c",
            "export PATH=\"/usr/bin:/bin:/usr/local/bin:$PATH\"; " +
            "for f in " +
            "/usr/share/applications/*.desktop " +
            "/usr/local/share/applications/*.desktop " +
            "/home/tanishk/.local/share/applications/*.desktop " +
            "; do " +
            "[ -f \"$f\" ] || continue; " +
            "type=$(grep -m1 '^Type=' \"$f\" | cut -d= -f2-); " +
            "[ -n \"$type\" ] && [ \"$type\" != \"Application\" ] && continue; " +
            "grep -qm1 '^NoDisplay=true' \"$f\" && continue; " +
            "grep -qm1 '^Hidden=true' \"$f\" && continue; " +
            "grep -qm1 '^Terminal=true' \"$f\" && continue; " +
            "name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "[ -z \"$name\" ] && continue; " +
            "exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/%[a-zA-Z]//g'); " +
            "[ -z \"$exec\" ] && continue; " +
            "icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "echo \"$name;;$exec;;$icon\"; " +
            "done"]
        running: false
        property var buffer: []
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (!line) return
                let p = line.split(";;")
                quickLaunchScanProc.buffer.push({ name: p[0] || "", exec: p[1] || "", icon: p[2] || "" })
            }
        }
        stderr: SplitParser {
            onRead: data => console.log("QuickLauncher scan stderr:", data)
        }
        onRunningChanged: if (!running) {
            let byName = {}
            for (const a of quickLaunchScanProc.buffer) byName[a.name] = a
            root.quickLaunchInstalled = Object.values(byName).sort((a, b) => a.name.localeCompare(b.name))
            quickLaunchScanProc.buffer = []
        }
    }

   Process {
    id: quickLaunchLaunchProc
    property string cmd: ""
    // Dropped the trailing " &" — Process.running already spawns detached,
    // backgrounding inside the shell too just swallows the exit code and
    // any error output, which is exactly what's hiding your bug.
    command: ["sh", "-c", cmd + " > /tmp/quicklaunch-last.log 2>&1"]
    stdout: SplitParser {
        onRead: data => console.log("QuickLauncher launch stdout:", data)
    }
    stderr: SplitParser {
        onRead: data => console.log("QuickLauncher launch stderr:", data)
    }
    onExited: (exitCode, exitStatus) => {
        console.log("QuickLauncher launch exited:", exitCode, exitStatus)
    }
}

    // ── MATUGEN ─────────────────────────────────────────────────────────────
    Process {
        id: matugenProc
        command: ["sh", "-c", "jq -c . /home/tanishk/.config/rice/matugen/colors.json"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed.colors) {
                        let c = parsed.colors
                        // Force the update to the properties
                        root.fgColor = c.on_surface
                        root.accentColor = c.primary
                        root.errorColor = c.error
                        root.btColor = c.tertiary
                        console.log("Colors updated successfully")
                    }
                } catch(e) { console.log("Matugen parse error:", e) }
            }
        }
    }
    // Increase the delay from 1000ms to 2000ms to ensure the file exists
    Timer { 
        interval: 2000; 
        running: true; 
        repeat: false; 
        triggeredOnStart: true; 
        onTriggered: matugenProc.running = true 
    }
    Process {
        id: matugenWatcher
        // Monitoring the folder instead of the file ensures the watch persists
        // even if matugen deletes and recreates colors.json
        command: ["sh", "-c", "inotifywait -m -e modify,moved_to /home/tanishk/.config/rice/matugen/"]
        running: true
        stdout: SplitParser { 
            onRead: data => { 
                console.log("Change detected in matugen directory");
                matugenProc.running = true 
            } 
        }
    }

    // ── CLOCK ────────────────────────────────────────────────────────────────
    Timer { 
        interval: 10000;
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.clockStr = Qt.formatDateTime(new Date(), "HH:mm") 
    }

    // ── MUSIC ────────────────────────────────────────────────────────────────
  Process {
        id: musicMeta
        command: ["playerctl", "metadata", "--format", "{{title}};;{{artist}};;{{playerName}};;{{mpris:length}}"]
        running: false
        stdout: SplitParser { onRead: data => {
            let p = data.trim().split(";;")
            root.musicTitle = p[0] || ""
            root.musicArtist = p[1] || ""
            
            // App Name Parser
            let rawPlayer = p[2] ? p[2].trim().toLowerCase() : ""
            let finalPlayer = "Media"
            if (rawPlayer.includes("brave") || rawPlayer.includes("chromium") || rawPlayer.includes("plasma-browser")) {
                finalPlayer = "Brave"
            } else if (rawPlayer.includes("firefox") || rawPlayer.includes("mozilla")) {
                finalPlayer = "Firefox"
            } else if (rawPlayer.includes("spotify")) {
                finalPlayer = "Spotify"
            } else if (rawPlayer !== "") {
                finalPlayer = rawPlayer.charAt(0).toUpperCase() + rawPlayer.slice(1)
            }
            root.musicPlayer = finalPlayer

            // Length Parser
            let lenMicro = parseInt(p[3])
            if (!isNaN(lenMicro) && lenMicro > 0) root.musicLength = lenMicro / 1000000
            else root.musicLength = 1 // Prevent division by zero
        }}
    }
    Process {
        id: musicStatus;
        command: ["playerctl", "status"]; running: false
        stdout: SplitParser { onRead: data => { root.isPlaying = data.trim() === "Playing" } }
    }
    // Polls current track position
    Process {
        id: musicPosProc
        command: ["playerctl", "position"]
        running: false
        stdout: SplitParser { onRead: data => {
            let pos = parseFloat(data.trim())
            if (!isNaN(pos)) root.musicPosition = pos
        }}
    }
    
    // Polls PipeWire volume
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser { onRead: data => {
            let str = data.trim()
            root.sysMuted = str.includes("[MUTED]")
            let match = str.match(/[\d\.]+/)
            if (match) root.sysVolume = parseFloat(match[0])
        }}
    }
    Process {
        id: battProc
        command: ["sh", "-c", "echo \"$(cat /sys/class/power_supply/BAT1/capacity);$(cat /sys/class/power_supply/BAT1/status)\""]
        running: false
        stdout: SplitParser { onRead: data => { 
            let parts = data.trim().split(";");
            if (parts.length === 2) {
                root.battVal = parts[0];
                root.battStatus = parts[1];
            }
        }}
    }

    // ── SYSTEM INFO ──────────────────────────────────────────────────────────
    Process {
        id: wifiProc
        command: ["sh", "-c", "ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2-); hotspot=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '$2==\"802-11-wireless\" && tolower($1)~/hotspot/{print $1; exit}'); [ \"$ssid\" = \"$hotspot\" ] && echo \"\" || echo \"$ssid\""]
        running: false
        stdout: SplitParser { onRead: data => { root.wifiVal = data.trim() } }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "bt=$(bluetoothctl devices Connected | head -n1 | cut -d' ' -f3-); echo \"$bt\""]
        running: false
        stdout: SplitParser { onRead: data => { root.btVal = data.trim() } }
    }
    Process {
        id: ethProc
        command: ["sh", "-c", "dev=$(nmcli -t -f TYPE,STATE,DEVICE device | awk -F: '$1==\"ethernet\" && $2==\"connected\"{print $3; exit}'); echo \"$dev\""]
        running: false
        stdout: SplitParser { onRead: data => { root.ethVal = data.trim() } }
    }
    Process {
        id: cpuProc
        command: ["sh", "-c",
            "cat /proc/stat | awk 'NR==1{u=$2+$3+$4+$6+$7+$8; i=$5; print u,i}' > /tmp/.qs_cpu1; " +
            "sleep 0.5; " +
            "cat /proc/stat | awk 'NR==1{u=$2+$3+$4+$6+$7+$8; i=$5; print u,i}' | " +
            "awk '{getline l < \"/tmp/.qs_cpu1\"; split(l,a); du=$1-a[1]; di=$2-a[2]; dt=du+di; print (dt>0?int(100*du/dt):0)}'"]
        running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data); if (!isNaN(v)) root.cpuVal = v } }
    }
    Process {
        id: ramProc; command: ["sh", "-c", "free | awk '/Mem:/{print int($3/$2*100)}'"];  running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data); if (!isNaN(v)) root.ramVal = v } }
    }
    Process {
        id: tempProc
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp"]
        running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data); if (!isNaN(v)) root.tempVal = Math.round(v / 1000) } }
    }

    // ── VISUALIZER ───────────────────────────────────────────────────────────
Process {
    id: rustViz
    command: ["/home/tanishk/.config/rice/qs-visualizer/target/release/qs-visualizer"]
    running: true
    stdout: SplitParser { onRead: data => {
        try {
            let p = JSON.parse(data.trim())
            if (p.length === 32) root.visualizerData = p
        } catch(e) {}
    }}
}
    // ── ACTIONS ──────────────────────────────────────────────────────────────
    Process { id: wifiAction;     command: ["sh", "-c", "airctl &"] }
    Process { id: btAction;       command: ["sh", "-c", "blueman-manager &"] }
    Process { id: musicPlayPause; command: ["playerctl", "play-pause"] }
    Process { id: musicNext;      command: ["playerctl", "next"] }
    Process { id: musicPrev;      command: ["playerctl", "previous"] }
    Process { id: volSet; property real targetVol: 0.5; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVol.toFixed(2)] } 
    // ── POLL TIMERS ──────────────────────────────────────────────────────────
    Timer { 
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { cpuProc.running = true; ramProc.running = true; wifiProc.running = true; ethProc.running = true; btProc.running = true; battProc.running = true; tempProc.running = true; } 
    }
    Timer { 
        interval: 1000; running: true; repeat: true
        onTriggered: { 
            musicMeta.running = true; 
            musicStatus.running = true;
            musicPosProc.running = true; // NEW
            volProc.running = true;      // NEW
        } 
    }

   // ── BAR ──────────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 58
            color: "transparent"

            // Layer-shell surfaces don't get keyboard input by default (same
            // issue as QuickLauncherPicker's search box). "OnDemand" only
            // hands over focus on an actual pointer click on the surface —
            // hovering + forceActiveFocus() from the QML side isn't enough
            // to make niri/wlroots hand it over — so use "Exclusive" while
            // hovered to grab it immediately, same trick launcher-style
            // overlays like rofi/wofi use.
            WlrLayershell.keyboardFocus: quickLauncher.hovering ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // 1. Left Aligned
                RowLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    
                    SystemPill {
                        pillBg: root.pillBg; fgColor: root.fgColor
                        accentColor: root.accentColor; errorColor: root.errorColor
                        activeFont: root.activeFont
                        cpuVal: root.cpuVal; ramVal: root.ramVal
                        tempVal: root.tempVal 
                    }
                }

                // 1.5 Center Aligned — Quick App Launcher
                QuickLauncher {
                    id: quickLauncher
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    pillBg: root.pillBg; fgColor: root.fgColor
                    accentColor: root.accentColor; errorColor: root.errorColor
                    activeFont: root.activeFont

                    appsModel:    root.quickLaunchApps
                    currentIndex: root.quickLaunchIndex

                    onScrollNext:       root.quickLaunchScrollNext()
                    onScrollPrev:       root.quickLaunchScrollPrev()
                    onSelectRequested:  (index) => root.quickLaunchIndex = index
                    onLaunchRequested:  (app)   => root.quickLaunchLaunch(app)
                    onRemoveRequested:  (index) => root.quickLaunchRemoveApp(index)
                    onRequestOpenPicker: {
                        root.quickLaunchRefreshInstalled()
                        root.quickLauncherPickerOpen = true
                    }
                }

                // 2. Right Aligned
                RowLayout {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    
                    StatusPill {
                        pillBg: root.pillBg; fgColor: root.fgColor
                        accentColor: root.accentColor; errorColor: root.errorColor
                        btColor: root.btColor; activeFont: root.activeFont
                        
                        ethVal: root.ethVal
                        wifiVal: root.wifiVal; btVal: root.btVal
                        clockStr: root.clockStr; calendarOpen: root.calendarOpen
                        
                        battVal: root.battVal
                        battStatus: root.battStatus

                        onEthClicked:      wifiAction.running = true 
                        onWifiClicked:     wifiAction.running = true
                        onBtClicked:       btAction.running   = true
                        onClockClicked:    root.calendarOpen  = !root.calendarOpen
                        onPowerClicked:    root.powerMenuOpen = !root.powerMenuOpen
                        notifPanelOpen:    root.notifPanelOpen
                        
                        onBellClicked: {
                            root.powerMenuOpen  = false
                            root.calendarOpen   = false
                            root.notifPanelOpen = !root.notifPanelOpen
                        }
                    }
                }
            }
        }
    }

// ── MUSIC FLYOUT PANEL ───────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: musicFlyout
            screen: modelData
            anchors { right: true }
            color: "transparent"
            
            // THE FIX: Tells Niri NOT to push other tiled windows out of the way
            exclusiveZone: 0

            // The panel resizes dynamically based on this container
            implicitWidth: flyoutContainer.width
            implicitHeight: flyoutContainer.height

            Item {
                id: flyoutContainer
                // Expanded size vs slightly wider 16px collapsed trigger size
                width: panelState.isOpen ? 420 : 16 
                height: 185 // Matched to the new card height
                
                // OutExpo provides a snappier "pop out" feel
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                QtObject {
                    id: panelState
                    property bool isOpen: false
                }

                // HoverHandler is much more reliable than MouseArea for edge panels
                HoverHandler {
                    id: flyoutHover
                    onHoveredChanged: {
                        if (hovered) {
                            closeTimer.stop()
                            panelState.isOpen = true
                        } else {
                            closeTimer.restart()
                        }
                    }
                }

                // Debounce timer to prevent flickering during Wayland resizing
                Timer {
                    id: closeTimer
                    interval: 200 // 200ms grace period before closing
                    onTriggered: panelState.isOpen = false
                }

                // The redesigned pill itself
                MusicPill {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10 

                    accentColor: root.accentColor
                    fgColor: root.fgColor
                    activeFont: root.activeFont
                    musicTitle: root.musicTitle
                    visualizerData: root.visualizerData
                    isPlaying: root.isPlaying // Passed down for the play/pause icon toggle
                    
                    musicPosition: root.musicPosition
                    musicLength: root.musicLength
                    sysVolume: root.sysVolume
                    sysMuted: root.sysMuted
                    onVolumeChanged: (val) => { volSet.targetVol = val; volSet.running = true }
                    
                    onPrevClicked:      musicPrev.running      = true
                    onPlayPauseClicked: musicPlayPause.running = true
                    onNextClicked:      musicNext.running      = true

                    opacity: panelState.isOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                // A visual indicator line so you know where the hover zone is
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 2
                    width: 4
                    height: 30
                    radius: 2
                    color: root.accentColor
                    opacity: panelState.isOpen ? 0 : 0.8
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }
    // ── AGENDA + VAULT FLYOUT PANEL (LEFT EDGE) ──────────────────────────────
    // Mirrors musicFlyout exactly: hidden as a sliver, snaps out on hover,
    // tucks away on mouse-leave. All colors passed down are matugen-sourced
    // (root.fgColor / root.accentColor / etc.), nothing hardcoded here.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: agendaFlyout
            screen: modelData
            anchors { left: true }
            color: "transparent"

            // Same fix as musicFlyout: don't push tiled windows out of the way
            exclusiveZone: 0

            // Layer-shell surfaces don't get keyboard input by default (same
            // issue as QuickLauncher's search box — see barWindow above).
            // Grab focus while hovered so the task/scratchpad TextInputs
            // actually receive keystrokes.
            WlrLayershell.keyboardFocus: agendaHover.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            implicitWidth: agendaContainer.width
            implicitHeight: agendaContainer.height

            Item {
                id: agendaContainer
                // Expanded size vs a slightly wider 16px collapsed trigger sliver.
                // Driven by agendaVault.implicitWidth (not a hardcoded number)
                // because AgendaVaultCard's width now includes its side-by-side
                // emoji panel — a fixed 460 here would clip that panel off.
                width: agendaPanelState.isOpen ? agendaVault.implicitWidth + 20 : 16
                height: agendaVault.implicitHeight + 20

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                QtObject {
                    id: agendaPanelState
                    property bool isOpen: false
                }

                HoverHandler {
                    id: agendaHover
                    onHoveredChanged: {
                        if (hovered) {
                            agendaCloseTimer.stop()
                            agendaPanelState.isOpen = true
                        } else {
                            agendaCloseTimer.restart()
                        }
                    }
                }

                Timer {
                    id: agendaCloseTimer
                    interval: 200
                    onTriggered: agendaPanelState.isOpen = false
                }

                AgendaVaultCard {
                    id: agendaVault
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10

                    pillBg:      root.pillBg
                    fgColor:     root.fgColor
                    accentColor: root.accentColor
                    errorColor:  root.errorColor
                    btColor:     root.btColor
                    activeFont:  root.activeFont

                    opacity: agendaPanelState.isOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                // Hover-zone indicator line, same treatment as the music pill's
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 2
                    width: 4
                    height: 30
                    radius: 2
                    color: root.accentColor
                    opacity: agendaPanelState.isOpen ? 0 : 0.8
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }

    // ── CALENDAR ─────────────────────────────────────────────────────────────
    CalendarPopup {
        calendarOpen: root.calendarOpen
        accentColor:  root.accentColor
        fgColor:      root.fgColor
        activeFont:   root.activeFont
    }
    
    // ── POWER MENU ───────────────────────────────────────────────────────────
    PowerMenu {
        powerMenuOpen: root.powerMenuOpen
        accentColor:   root.accentColor
        fgColor:       root.fgColor
        errorColor:    root.errorColor
        activeFont:    root.activeFont
        btColor:       root.btColor

        // Network state forwarded from shell pollers
        wifiVal:  root.wifiVal
        ethVal:   root.ethVal
        btVal:    root.btVal

        // Safely resets the state in the parent without breaking the binding!
        onRequestClose: root.powerMenuOpen = false
    }
    
    LowBatteryPopup {
        battVal:     root.battVal
        battStatus:  root.battStatus
        accentColor: root.accentColor
        fgColor:     root.fgColor
        activeFont:  root.activeFont
    }
    
    NotifClipPanel {
        panelOpen:   root.notifPanelOpen
        accentColor: root.accentColor
        fgColor:     root.fgColor
        errorColor:  root.errorColor
        activeFont:  root.activeFont
        onRequestClose: root.notifPanelOpen = false
    }

    // ── QUICK LAUNCHER "ADD APP" POPUP ──────────────────────────────────────
    QuickLauncherPicker {
        open:           root.quickLauncherPickerOpen
        installedApps:  root.quickLaunchInstalled
        pillBg:         root.pillBg
        fgColor:        root.fgColor
        accentColor:    root.accentColor
        activeFont:     root.activeFont

        onAppPicked:    (app) => root.quickLaunchAddApp(app)
        onRequestClose: root.quickLauncherPickerOpen = false
    }
}
