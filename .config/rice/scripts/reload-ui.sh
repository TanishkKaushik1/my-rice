#!/usr/bin/env bash
# reload-ui.sh
# Restarts the quickshell-driven UI (bar, app-launcher, customization panel,
# task-manager) without restarting niri itself. Bound to Mod+Shift+C.
#
# Self-locates the rice root from this script's own path (scripts/ is
# one level under rice/), so it works no matter whose $HOME it's in.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
RICE_DIR="$(dirname -- "$SCRIPT_DIR")"

# ponytail: matching by command-line substring is a soft ceiling -- if a
# process is renamed/wrapped differently this stops finding it. Upgrade
# path: have quickshell instances register a pidfile under
# XDG_RUNTIME_DIR/rice/ instead and kill by pid.
stop() {
    pkill -f -- "$1" 2>/dev/null
}

echo "Reloading UI..."

stop "${RICE_DIR}/scripts/launch-bar.sh"
stop "quickshell -c ${RICE_DIR}/app-launcher"
stop "quickshell -c ${RICE_DIR}/customization"
stop "qs -p ${RICE_DIR}/task-manager"

# give them a moment to actually exit before we respawn on top of them
sleep 0.3

"${RICE_DIR}/scripts/launch-bar.sh" >/dev/null 2>&1 &
disown
quickshell -c "${RICE_DIR}/app-launcher" >/dev/null 2>&1 &
disown
quickshell -c "${RICE_DIR}/customization" >/dev/null 2>&1 &
disown
qs -p "${RICE_DIR}/task-manager" >/dev/null 2>&1 &
disown
 notify-send -a "UI Reload" "UI Reloaded" "UI reloaded successfully" 2>/dev/null
echo "Done."