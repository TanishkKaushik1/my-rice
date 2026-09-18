#!/usr/bin/env bash
# kill_process.sh
# Terminates a process by PID. Called from ProcessContextMenu.qml's "End Task" action.
#
# Usage: kill_process.sh <pid>
#
# Behavior (mirrors Windows Task Manager's "End Task"):
#   1. Try SIGTERM first (graceful shutdown, lets the app clean up)
#   2. Wait briefly
#   3. If still alive, escalate to SIGKILL (force kill)
#
# Outputs a small JSON result so QML can show a toast/notification on success or failure.

set -uo pipefail

pid="${1:-}"

if [[ -z "$pid" ]]; then
    echo '{"success":false,"error":"no_pid_provided"}'
    exit 1
fi

if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    echo '{"success":false,"error":"invalid_pid"}'
    exit 1
fi

if ! kill -0 "$pid" 2>/dev/null; then
    echo "{\"success\":false,\"pid\":${pid},\"error\":\"process_not_found\"}"
    exit 1
fi

# Step 1: graceful
kill -TERM "$pid" 2>/dev/null

# Step 2: wait up to ~1s for it to exit
for _ in $(seq 1 10); do
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "{\"success\":true,\"pid\":${pid},\"method\":\"SIGTERM\"}"
        exit 0
    fi
    sleep 0.1
done

# Step 3: force kill
if kill -KILL "$pid" 2>/dev/null; then
    echo "{\"success\":true,\"pid\":${pid},\"method\":\"SIGKILL\"}"
    exit 0
else
    echo "{\"success\":false,\"pid\":${pid},\"error\":\"kill_failed_check_permissions\"}"
    exit 1
fi