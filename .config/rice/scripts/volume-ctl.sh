#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# volume-ctl.sh  —  Wallpaper volume control for linux-wallpaperengine
#
# Usage:
#   volume-ctl.sh up              # +10
#   volume-ctl.sh down            # -10
#   volume-ctl.sh mute            # set 0
#   volume-ctl.sh unmute          # restore last non-zero volume
#   volume-ctl.sh set <0-100>     # set exact value
#   volume-ctl.sh get             # print current volume
#
# Bind to keys in niri config.kdl:
#   Mod+Shift+Up   { spawn "bash" "/path/to/volume-ctl.sh" "up"; }
#   Mod+Shift+Down { spawn "bash" "/path/to/volume-ctl.sh" "down"; }
#   Mod+Shift+M    { spawn "bash" "/path/to/volume-ctl.sh" "mute"; }
# ─────────────────────────────────────────────────────────────────────────────

LWE_CTL="${HOME}/.config/rice/scripts/lwe-ctl.sh"
STATE_FILE="/tmp/lwe-state.json"
MUTE_CACHE="/tmp/lwe-premute-volume"
LOG_TAG="[volume-ctl]"
STEP=10

log() { echo "${LOG_TAG} $*"; }
die() { log "ERROR: $*"; exit 1; }

[[ -x "$LWE_CTL" ]] || die "lwe-ctl.sh not found or not executable at $LWE_CTL"

state_get() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] || { echo ""; return; }
    grep -o "\"${key}\":[^,}]*" "$STATE_FILE" \
        | head -1 \
        | sed 's/.*://; s/[" ]//g'
}

clamp() {
    local val="$1"
    (( val < 0   )) && val=0
    (( val > 100 )) && val=100
    echo "$val"
}

notify_volume() {
    local vol="$1"
    # Show OSD if available (dunst / libnotify)
    if command -v notify-send > /dev/null 2>&1; then
        notify-send -t 1500 -h string:x-dunst-stack-tag:lwe-volume \
            -h "int:value:${vol}" \
            "Wallpaper volume" "${vol}%" 2>/dev/null || true
    fi
}

CMD="${1:-}"
shift || true

case "$CMD" in
    up)
        cur=$(state_get volume)
        cur=${cur:-50}
        new=$(clamp $(( cur + STEP )))
        log "Volume $cur → $new"
        "$LWE_CTL" volume "$new"
        notify_volume "$new"
        ;;

    down)
        cur=$(state_get volume)
        cur=${cur:-50}
        new=$(clamp $(( cur - STEP )))
        log "Volume $cur → $new"
        "$LWE_CTL" volume "$new"
        notify_volume "$new"
        ;;

    mute)
        cur=$(state_get volume)
        cur=${cur:-50}
        if [[ "$cur" -eq 0 ]]; then
            log "Already muted"
            exit 0
        fi
        echo "$cur" > "$MUTE_CACHE"
        log "Muting (saved $cur)"
        "$LWE_CTL" volume 0
        notify_volume 0
        ;;

    unmute)
        if [[ -f "$MUTE_CACHE" ]]; then
            prev=$(cat "$MUTE_CACHE")
            rm -f "$MUTE_CACHE"
        else
            prev=50
        fi
        log "Unmuting → $prev"
        "$LWE_CTL" volume "$prev"
        notify_volume "$prev"
        ;;

    set)
        val="$1"
        [[ -z "$val" ]] && die "set requires a value 0-100"
        val=$(clamp "$val")
        log "Setting volume → $val"
        "$LWE_CTL" volume "$val"
        notify_volume "$val"
        ;;

    get)
        vol=$(state_get volume)
        echo "${vol:-unknown}"
        ;;

    *)
        echo "Usage: volume-ctl.sh <up|down|mute|unmute|set <N>|get>"
        exit 1
        ;;
esac
