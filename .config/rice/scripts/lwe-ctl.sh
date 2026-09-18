#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lwe-ctl.sh  —  Central IPC shim for linux-wallpaperengine
#
# Usage:
#   lwe-ctl.sh set <workshop_id_or_path> [--volume 0-100] [--fps 30]
#   lwe-ctl.sh pause
#   lwe-ctl.sh resume
#   lwe-ctl.sh volume <0-100>
#   lwe-ctl.sh status
#   lwe-ctl.sh stop
#
# State file: /tmp/lwe-state.json
#   { "pid": 12345, "id": "1234567890", "volume": 50, "fps": 30,
#     "paused": false, "output": "eDP-1" }
# ─────────────────────────────────────────────────────────────────────────────

LWE_BIN="linux-wallpaperengine"
STATE_FILE="/tmp/lwe-state.json"
LOG_TAG="[lwe-ctl]"

WORKSHOP_DIR="${HOME}/.local/share/Steam/steamapps/workshop/content/431960"
ASSETS_DIR="${HOME}/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

# Defaults — override via args or state
DEFAULT_VOLUME=50
DEFAULT_FPS=30
DEFAULT_OUTPUT="eDP-1"   # change to your monitor name (run: niri msg outputs)

# ─── helpers ─────────────────────────────────────────────────────────────────

log()  { echo "${LOG_TAG} $*"; }
die()  { log "ERROR: $*"; exit 1; }

# Check binary exists
require_lwe() {
    command -v "$LWE_BIN" > /dev/null 2>&1 \
        || die "binary '$LWE_BIN' not found in PATH. Install linux-wallpaperengine-git."
}

# Read a field from the JSON state file
# Usage: state_get pid
state_get() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] || { echo ""; return; }
    # simple key extraction — no jq dependency
    grep -o "\"${key}\":[^,}]*" "$STATE_FILE" \
        | head -1 \
        | sed 's/.*://; s/[" ]//g'
}

# Write full state (always overwrites)
state_write() {
    local pid="$1" id="$2" volume="$3" fps="$4" paused="$5" output="$6"
    cat > "$STATE_FILE" <<EOF
{
  "pid": ${pid},
  "id": "${id}",
  "volume": ${volume},
  "fps": ${fps},
  "paused": ${paused},
  "output": "${output}"
}
EOF
}

state_set_field() {
    local key="$1" value="$2"
    [[ -f "$STATE_FILE" ]] || return
    # In-place sed replace for the field
    sed -i "s/\"${key}\": *[^,}]*/\"${key}\": ${value}/" "$STATE_FILE"
}

# Kill any running LWE process gracefully
kill_lwe() {
    local pid
    pid=$(state_get pid)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        log "Stopping LWE (PID $pid)"
        kill "$pid" 2>/dev/null
        # Wait up to 2s for clean exit
        local i=0
        while kill -0 "$pid" 2>/dev/null && [[ $i -lt 20 ]]; do
            sleep 0.1; ((i++))
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
    # Also catch any orphaned processes not in state
    pkill -f "linux-wallpaperengine" 2>/dev/null || true
}

# Detect wallpaper type from project.json (scene / video / web)
detect_type() {
    local id="$1"
    local proj="${WORKSHOP_DIR}/${id}/project.json"
    [[ -f "$proj" ]] || { echo "unknown"; return; }
    grep -o '"type" *: *"[^"]*"' "$proj" \
        | head -1 \
        | grep -o '"[^"]*"$' \
        | tr -d '"'
}

# ─── commands ────────────────────────────────────────────────────────────────

cmd_set() {
    require_lwe

    local id="" volume="$DEFAULT_VOLUME" fps="$DEFAULT_FPS" output="$DEFAULT_OUTPUT"

    # Parse args: set <id> [--volume N] [--fps N] [--output NAME]
    id="$1"; shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --volume) volume="$2"; shift 2 ;;
            --fps)    fps="$2";    shift 2 ;;
            --output) output="$2"; shift 2 ;;
            *)        shift ;;
        esac
    done

    [[ -z "$id" ]] && die "set requires a workshop ID or path"

    # Inherit volume/fps/output from current state if not overridden
    local cur_vol cur_fps cur_out
    cur_vol=$(state_get volume); cur_fps=$(state_get fps); cur_out=$(state_get output)
    [[ -n "$cur_vol" ]] && volume="$cur_vol"
    [[ -n "$cur_fps" ]] && fps="$cur_fps"
    [[ -n "$cur_out" ]] && output="$cur_out"

    # Resolve path: if it looks like a plain number treat as workshop ID
    local bg_path
    if [[ "$id" =~ ^[0-9]+$ ]]; then
        bg_path="${WORKSHOP_DIR}/${id}"
        [[ -d "$bg_path" ]] || die "Workshop item not found: $bg_path"
    else
        # Treat as direct path
        bg_path="$id"
        id=$(basename "$id")
        [[ -e "$bg_path" ]] || die "Path not found: $bg_path"
    fi

    log "Setting wallpaper → ID: $id | output: $output | vol: $volume | fps: $fps"

    # Kill current instance
    kill_lwe

    # Build command
    local cmd=(
        "$LWE_BIN"
        --screen-root "$output"
        --bg "$bg_path"
        --volume "$volume"
        --fps "$fps"
    )

    # Add assets dir if it exists (needed when not using AUR package)
    [[ -d "$ASSETS_DIR" ]] && cmd+=(--assets-dir "$ASSETS_DIR")

    log "Launching: ${cmd[*]}"

    # Launch in background, detach from terminal
    nohup "${cmd[@]}" > /tmp/lwe.log 2>&1 &
    local new_pid=$!

    # Give it a moment to start (or fail fast)
    sleep 0.5
    if ! kill -0 "$new_pid" 2>/dev/null; then
        log "ERROR: LWE exited immediately — check /tmp/lwe.log"
        cat /tmp/lwe.log | tail -5
        exit 1
    fi

    state_write "$new_pid" "$id" "$volume" "$fps" "false" "$output"
    log "LWE running (PID $new_pid)"
}

cmd_pause() {
    local pid
    pid=$(state_get pid)
    [[ -z "$pid" ]] && { log "No running LWE instance"; return; }
    kill -0 "$pid" 2>/dev/null || { log "PID $pid not alive"; return; }

    local paused
    paused=$(state_get paused)
    [[ "$paused" == "true" ]] && { log "Already paused"; return; }

    log "Pausing LWE (PID $pid)"
    kill -STOP "$pid"
    state_set_field "paused" "true"
    log "Paused"
}

cmd_resume() {
    local pid
    pid=$(state_get pid)
    [[ -z "$pid" ]] && { log "No running LWE instance"; return; }

    local paused
    paused=$(state_get paused)
    [[ "$paused" != "true" ]] && { log "Not paused"; return; }

    log "Resuming LWE (PID $pid)"
    kill -CONT "$pid"
    state_set_field "paused" "false"
    log "Resumed"
}

cmd_volume() {
    local vol="$1"
    [[ -z "$vol" ]] && die "volume requires a value 0-100"
    [[ "$vol" =~ ^[0-9]+$ ]] && [[ "$vol" -le 100 ]] || die "volume must be 0-100"

    local pid id fps output
    pid=$(state_get pid)
    id=$(state_get id)
    fps=$(state_get fps)
    output=$(state_get output)

    [[ -z "$pid" ]] && { log "No running LWE — updating state only"; state_set_field "volume" "$vol"; return; }

    local wp_type
    wp_type=$(detect_type "$id")
    log "Wallpaper type: $wp_type | new volume: $vol"

    if [[ "$wp_type" == "video" ]]; then
        # For video (mpv backend) — try PipeWire sink volume via wpctl
        # Find the sink input owned by our LWE PID
        if command -v wpctl > /dev/null 2>&1; then
            local sink_id
            sink_id=$(wpctl status 2>/dev/null \
                | grep -i "wallpaper\|lwe\|mpv" \
                | grep -o '[0-9]\+\.' \
                | head -1 \
                | tr -d '.')
            if [[ -n "$sink_id" ]]; then
                wpctl set-volume "$sink_id" "${vol}%"
                state_set_field "volume" "$vol"
                log "Volume set via wpctl (sink $sink_id)"
                return
            fi
        fi
        log "wpctl sink not found — relaunching with new volume"
    fi

    # Scene wallpapers (and video fallback): relaunch with new volume
    cmd_set "$id" --volume "$vol" --fps "$fps" --output "$output"
}

cmd_stop() {
    log "Stopping LWE"
    kill_lwe
    rm -f "$STATE_FILE"
    log "Stopped"
}

cmd_status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No state file — LWE not running"
        return
    fi
    local pid id volume fps paused output
    pid=$(state_get pid)
    id=$(state_get id)
    volume=$(state_get volume)
    fps=$(state_get fps)
    paused=$(state_get paused)
    output=$(state_get output)

    local alive="no"
    kill -0 "$pid" 2>/dev/null && alive="yes"

    echo "─────────────────────────────"
    echo " LWE status"
    echo "─────────────────────────────"
    echo " PID:     $pid (alive: $alive)"
    echo " ID:      $id"
    echo " Output:  $output"
    echo " Volume:  $volume"
    echo " FPS:     $fps"
    echo " Paused:  $paused"
    echo " Type:    $(detect_type "$id")"
    echo "─────────────────────────────"
}

# ─── dispatch ────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
    set)    cmd_set    "$@" ;;
    pause)  cmd_pause       ;;
    resume) cmd_resume      ;;
    volume) cmd_volume "$@" ;;
    stop)   cmd_stop        ;;
    status) cmd_status      ;;
    *)
        echo "Usage: lwe-ctl.sh <set|pause|resume|volume|stop|status>"
        echo ""
        echo "  set <id> [--volume N] [--fps N] [--output NAME]"
        echo "  pause"
        echo "  resume"
        echo "  volume <0-100>"
        echo "  stop"
        echo "  status"
        exit 1
        ;;
esac
