#!/usr/bin/env bash
# toggle-record.sh
LOCKFILE="/tmp/.wf-recorder-running"
GEOM_CACHE="/tmp/.wf-recorder-geometry"
ACTION="${1:-toggle}"

CONFIG="$HOME/.config/rice/recording-settings.conf"

# ── Defaults (used if config is missing or a key isn't set) ───────────────
CAPTURE_MODE="screen"      # screen | region | window
AUDIO_SOURCE="system"      # none | mic | system | both
INCLUDE_CURSOR="1"         # 1 | 0
VIDEO_FORMAT="mp4"         # mp4 | mkv | webm
FRAMERATE="60"
QUALITY="high"             # low | medium | high | lossless
OUTPUT_DIR="$HOME/Videos/Recordings"

[ -f "$CONFIG" ] && source "$CONFIG"

OUTDIR="$(eval echo "$OUTPUT_DIR")"

is_running() {
    [ -f "$LOCKFILE" ]
}

# ── Quality → x264 CRF (lower = better/bigger). Lossless switches codec. ──
crf_for_quality() {
    case "$QUALITY" in
        low)      echo 32 ;;
        medium)   echo 26 ;;
        high)     echo 20 ;;
        lossless) echo 0  ;;
        *)        echo 23 ;;
    esac
}

# ── Resolve the geometry string for -g, based on CAPTURE_MODE ─────────────
# Screen  -> no -g flag (wf-recorder captures the focused output)
# Region  -> interactive slurp selection, cached so stop/status can reuse it
# Window  -> click-to-select via slurp -w against the compositor's toplevels
resolve_geometry() {
    case "$CAPTURE_MODE" in
        region)
            if command -v slurp >/dev/null 2>&1; then
                slurp
            fi
            ;;
        window)
            if command -v slurp >/dev/null 2>&1; then
                if command -v niri >/dev/null 2>&1; then
                    # niri exposes window geometry via IPC; slurp -w still works
                    # fine here since it reads wlr-foreign-toplevel + layer info.
                    slurp -w -b 00000000 -c "ff0000ff"
                else
                    slurp -w
                fi
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── Audio source → wf-recorder --audio value(s) ────────────────────────────
# wf-recorder only accepts one --audio device per run. "both" mixes mic +
# system monitor into a temporary combined sink via pactl so a single
# --audio flag can capture the mix; the sink is torn down again on stop.
COMBINED_SINK_NAME="niri_rice_record_mix"

detect_system_monitor() {
    local sink_id audio_device monitor
    sink_id=$(wpctl status | awk '/Audio/,/Video/' | grep -E '^\s+[├└─]+\s+[0-9]+\.' | grep -i 'sink\|output\|speaker\|headphone\|hdmi' | head -n1 | grep -oP '^\s+[├└─]+\s+\K[0-9]+')

    if [ -n "$sink_id" ]; then
        audio_device=$(wpctl inspect "$sink_id" 2>/dev/null | grep 'node.name' | head -n1 | sed 's/.*= "\(.*\)".*/\1/')
        monitor="${audio_device}.monitor"
    fi

    if [ -z "$monitor" ]; then
        monitor=$(pactl list short sources | grep monitor | grep -v input | head -n1 | awk '{print $2}')
    fi

    [ -z "$monitor" ] && monitor="@DEFAULT_MONITOR@"
    echo "$monitor"
}

detect_mic() {
    pactl get-default-source 2>/dev/null
}

setup_audio() {
    case "$AUDIO_SOURCE" in
        none)
            AUDIO_ARGS=()
            ;;
        mic)
            AUDIO_ARGS=(--audio="$(detect_mic)")
            ;;
        system)
            AUDIO_ARGS=(--audio="$(detect_system_monitor)")
            ;;
        both)
            local mic sysmon
            mic=$(detect_mic)
            sysmon=$(detect_system_monitor)
            if command -v pactl >/dev/null 2>&1; then
                pactl unload-module 2>/dev/null || true
                pactl load-module module-null-sink sink_name="$COMBINED_SINK_NAME" sink_properties=device.description="rice-record-mix" >/tmp/.wf-recorder-mix-module 2>/dev/null
                pactl load-module module-loopback source="$mic" sink="$COMBINED_SINK_NAME" >>/tmp/.wf-recorder-mix-module 2>/dev/null
                pactl load-module module-loopback source="$sysmon" sink="$COMBINED_SINK_NAME" >>/tmp/.wf-recorder-mix-module 2>/dev/null
                AUDIO_ARGS=(--audio="${COMBINED_SINK_NAME}.monitor")
            else
                AUDIO_ARGS=(--audio="$sysmon")
            fi
            ;;
        *)
            AUDIO_ARGS=(--audio="$(detect_system_monitor)")
            ;;
    esac
}

teardown_audio() {
    if [ "$AUDIO_SOURCE" = "both" ] && [ -f /tmp/.wf-recorder-mix-module ]; then
        while read -r mod_id; do
            [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
        done < <(pactl list short modules | grep "$COMBINED_SINK_NAME" | awk '{print $1}')
        rm -f /tmp/.wf-recorder-mix-module
    fi
}

start_recording() {
    if ! is_running; then
        mkdir -p "$OUTDIR"
        local ext="$VIDEO_FORMAT"
        OUTFILE="$OUTDIR/screencast_$(date +%Y%m%d_%H%M%S).${ext}"

        local geometry
        geometry="$(resolve_geometry)"

        # Region/window mode with nothing selected (user hit Escape) -> abort
        if [ "$CAPTURE_MODE" != "screen" ] && [ -z "$geometry" ]; then
            notify-send -a "rice" "Screen Recording" "Selection cancelled" 2>/dev/null
            return 1
        fi
        echo "$geometry" > "$GEOM_CACHE"

        setup_audio
        echo "Using audio source: ${AUDIO_ARGS[*]:-none} | mode: $CAPTURE_MODE | fps: $FRAMERATE | quality: $QUALITY | cursor: $INCLUDE_CURSOR" > /tmp/wf-recorder.log

        local codec_args=(--codec libx264 --pixel-format yuv420p -x "crf=$(crf_for_quality)")
        if [ "$QUALITY" = "lossless" ]; then
            codec_args=(--codec libx264rgb -x "crf=0")
        fi

        local geom_args=()
        [ -n "$geometry" ] && geom_args=(-g "$geometry")

        local cursor_args=()
        [ "$INCLUDE_CURSOR" = "0" ] && cursor_args=(--no-cursor)

        touch "$LOCKFILE"
        setsid wf-recorder \
            "${geom_args[@]}" \
            "${AUDIO_ARGS[@]}" \
            "${cursor_args[@]}" \
            --framerate "$FRAMERATE" \
            "${codec_args[@]}" \
            --file "$OUTFILE" \
            >> /tmp/wf-recorder.log 2>&1 &
        disown $!
    fi
}

stop_recording() {
    if is_running; then
        killall -SIGINT wf-recorder 2>/dev/null
        sleep 0.5
        rm -f "$LOCKFILE" "$GEOM_CACHE"
        teardown_audio
    fi
}

case "$ACTION" in
    status)
        is_running && echo "recording" || echo "stopped"
        ;;
    stop)
        stop_recording
        ;;
    start)
        start_recording
        ;;
    toggle)
        if is_running; then
            stop_recording
        else
            start_recording
        fi
        ;;
    *)
        echo "Usage: $0 [start|stop|toggle|status]" >&2
        exit 1
        ;;
esac
