import QtQuick
import "root:/services" as Services

// ProcessModel.qml
// Groups processes sharing the same name (e.g. multiple "code" or "brave"
// PIDs belonging to one Electron-style app) into a single collapsible row,
// mirroring Win11 Task Manager's "App Name (11)" grouping.
//
// Row shapes in `rows`:
//   Single process:  { pid, name, cpu, mem_mb, mem_percent, user,
//                       isGroup:false, groupCount:1, indent:0, childPids:[pid] }
//   Group parent:     { pid:-1, name, cpu:<summed>, mem_mb:<summed>,
//                        mem_percent:<summed>, user, isGroup:true,
//                        groupCount:N, indent:0, childPids:[...] }
//   Expanded child:    same as single process shape but indent:1
//
// "End task" on a group row passes childPids (all PIDs) to
// ProcessService.killGroup(), so ending the group actually closes the whole
// app instead of just one process/tab/renderer.
//
// NOTE: `rows` is a plain JS array, NOT a QML ListModel. ListModel's dynamic
// roles don't reliably preserve array-typed values (childPids was silently
// coming back as `undefined` in delegates) -- binding a ListView directly to
// a plain array sidesteps QML's role-type coercion entirely and keeps
// nested arrays/objects intact. Delegates should use `required property var
// modelData` instead of `model.xxx` role access.
//
// Usage:
//   ProcessModel { id: processModel }
//   ListView { model: processModel.rows; delegate: ProcessRow { required property var modelData; pid: modelData.pid; ... } }
//   processModel.toggleGroup("code")  -- called from ProcessRow's expand arrow

Item {
    id: root

    property var rows: []

    // Which group names are currently expanded, e.g. { "code": true }
    property var expandedGroups: ({})

    // Cached so toggleGroup() can re-render immediately without waiting
    // for the next poll cycle.
    property var _lastProcesses: []

    Connections {
        target: Services.ProcessService
        function onFilteredProcessesChanged() {
            root._lastProcesses = Services.ProcessService.filteredProcesses
            root._sync(root._lastProcesses)
        }
    }

    Component.onCompleted: {
        root._lastProcesses = Services.ProcessService.filteredProcesses
        root._sync(root._lastProcesses)
    }

    function toggleGroup(name) {
        const next = Object.assign({}, root.expandedGroups)
        next[name] = !next[name]
        root.expandedGroups = next
        root._sync(root._lastProcesses) // re-render immediately
    }

    function _sync(processes) {
        const valid = processes.filter(p => p && p.pid !== undefined && p.pid !== null)

        // ---- Group by name ----
        const groups = {} // name -> array of process objects
        for (const p of valid) {
            if (!groups[p.name]) groups[p.name] = []
            groups[p.name].push(p)
        }

        // ---- Build flat display rows ----
        const newRows = []
        for (const name in groups) {
            const members = groups[name]

            if (members.length === 1) {
                const p = members[0]
                newRows.push({
                    pid: p.pid,
                    name: p.name,
                    cpu: p.cpu !== undefined ? p.cpu : 0,
                    mem_mb: p.mem_mb !== undefined ? p.mem_mb : 0,
                    mem_percent: p.mem_percent !== undefined ? p.mem_percent : 0,
                    user: p.user !== undefined ? p.user : "",
                    isGroup: false,
                    groupCount: 1,
                    indent: 0,
                    childPids: [p.pid]
                })
                continue
            }

            // ---- Group parent row: summed totals ----
            let sumCpu = 0, sumMem = 0, sumMemPct = 0
            const childPids = []
            for (const p of members) {
                sumCpu += (p.cpu || 0)
                sumMem += (p.mem_mb || 0)
                sumMemPct += (p.mem_percent || 0)
                childPids.push(p.pid)
            }

            newRows.push({
                pid: -1,
                name: name,
                cpu: sumCpu,
                mem_mb: sumMem,
                mem_percent: sumMemPct,
                user: members[0].user !== undefined ? members[0].user : "",
                isGroup: true,
                groupCount: members.length,
                indent: 0,
                childPids: childPids
            })

            if (root.expandedGroups[name]) {
                // Sort children by CPU descending under their parent
                const sortedMembers = members.slice().sort((a, b) => b.cpu - a.cpu)
                for (const p of sortedMembers) {
                    newRows.push({
                        pid: p.pid,
                        name: p.name,
                        cpu: p.cpu !== undefined ? p.cpu : 0,
                        mem_mb: p.mem_mb !== undefined ? p.mem_mb : 0,
                        mem_percent: p.mem_percent !== undefined ? p.mem_percent : 0,
                        user: p.user !== undefined ? p.user : "",
                        isGroup: false,
                        groupCount: 1,
                        indent: 1,
                        childPids: [p.pid]
                    })
                }
            }
        }

        // ---- Sort top-level rows by cpu descending (groups compete using their summed cpu) ----
        newRows.sort((a, b) => b.cpu - a.cpu)

        // Full replace -- grouping collapses ~300 raw processes down to a
        // much smaller visible row count, so this stays cheap even without
        // diffing. Reassigning the whole array (rather than mutating) is
        // what makes ListView pick up the change via the property binding.
        root.rows = newRows
    }
}
