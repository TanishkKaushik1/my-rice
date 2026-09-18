#!/usr/bin/env bash
# gaming-toggle.sh — manual-only gaming mode toggle (v2: CPU/thermal focused)
# Called ONLY by PowerMenu.qml. No daemon, no auto-detection.
#
# What it does now (RAM is no longer the constraint — CPU headroom + sustained
# clocks/thermals are):
#   - pause/resume the animated wallpaper (LWE) + mute/unmute its audio
#   - set power-profiles-daemon to performance/balanced — on your system this
#     is the authoritative intel_pstate control, cpupower conflicts with it
#   - switch ASUS platform profile (asusctl) to Performance — this is what
#     actually drives fan curve + power limits on TUF/ROG boards
#   - stop known background CPU-spike daemons (indexing/search) — no restore
#     needed, they respawn via systemd on their own
#   - kill a fixed list of apps you don't want eating cores while gaming
#   - deprioritize (renice + ionice), not kill, everything else that's left
#     running so a stray background spike can't steal cycles from the game
#   - lower vm.swappiness while gaming, restore your default after
#   - freeze/resume a few heavy dev tools (unchanged from before)
#   - write/remove a flag file so PowerMenu.qml's poller reflects state

LWE_CTL="${HOME}/.config/rice/scripts/lwe-ctl.sh"
VOLUME_CTL="${HOME}/.config/rice/scripts/volume-ctl.sh"
FLAG="/tmp/.wallpaper-gamemode"
NICE_STATE="/tmp/.gaming-toggle-nice-state"
LOG_TAG="[gaming-toggle]"
SELF_PID=$$

PROTECTED_REGEX="curseforge"

# Restore-to-default swappiness if we can't read the current value for
# some reason before stashing it.
DEFAULT_SWAPPINESS=60
GAMING_SWAPPINESS=10

# Suspended (SIGSTOP) while gaming, resumed (SIGCONT) after — not killed,
# so your editor/LSP state is exactly as you left it.
AUTO_RESUME_PROCESSES=(
    "rust-analyzer"
    "tsserver"
    "/opt/visual-studio-code/code"
    "code-oss"
    "clangd"
    "gopls"
    "pyright"
)

# Terminated while gaming. You restart these yourself when you want them.
MANUAL_START_PROCESSES=(
    "node" "npm" "vite" "cargo" "webpack" "esbuild"
    "chrome" "chromium" "firefox" "brave"
    "discord" "Discord" "vesktop" "webcord" "slack" "Slack"
)

# Stopped outright on "on" — pure CPU-spike background daemons, no state to
# preserve, they come back on their own via systemd/next login.
INDEX_DAEMONS=(
    "tracker-miner" "tracker3" "baloo_file" "trackerd"
)

# Everything else still running after the above gets renice'd instead of
# killed — this is the actual scheduler fix for the CPU bottleneck: it
# just loses priority contention, it doesn't disappear.
DEPRIORITIZE_NICE=15

log() { echo "${LOG_TAG} $*"; }

safe_pgrep() {
    local pat="$1"
    pgrep -af "$pat" 2>/dev/null \
        | grep -Ev "^${SELF_PID}[[:space:]]" \
        | grep -Eiv "$PROTECTED_REGEX" \
        | grep -Ei "(^|[^A-Za-z0-9_])${pat}([^A-Za-z0-9_]|$)" \
        | awk '{print $1}'
}

safe_pkill() {
    local sig="$1" pat="$2" pid
    while read -r pid; do
        [[ -z "$pid" ]] && continue
        kill "$sig" "$pid" 2>/dev/null
    done < <(safe_pgrep "$pat")
}

# ── CPU scheduling ─────────────────────────────────────────────────────────

# Renice + ionice everything that ISN'T one of our known lists, so background
# noise loses scheduling priority instead of being left to contend equally
# with the game for CPU time. Best-effort: wrapped per-pid, failures ignored.
#
# IMPORTANT: before touching a pid, its current nice/ionice is snapshotted to
# NICE_STATE. restore_priorities() replays that file to put EXACTLY those
# pids back to EXACTLY what they were — it never touches a pid we didn't
# touch here, and it never assumes "0 / best-effort-4" was the prior state.
deprioritize_the_rest() {
    local skip_regex
    skip_regex=$(IFS='|'; echo "${AUTO_RESUME_PROCESSES[*]}|${MANUAL_START_PROCESSES[*]}|niri|Xwayland|pipewire|wireplumber|quickshell|kitty|alacritty|foot|steam|wine|proton|gamescope|mangohud")
    : > "$NICE_STATE"
    local pid comm nice_val ionice_raw ionice_class ionice_prio touched=0
    while read -r pid comm; do
        [[ -z "$pid" || "$pid" == "$SELF_PID" ]] && continue
        [[ "$comm" =~ $skip_regex ]] && continue

        nice_val=$(ps -o nice= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -z "$nice_val" ]] && continue   # pid vanished between ps calls

        ionice_raw=$(ionice -p "$pid" 2>/dev/null)
        ionice_class="best-effort"; ionice_prio=4
        if [[ "$ionice_raw" =~ class:\ ([A-Za-z-]+) ]]; then
            ionice_class="${BASH_REMATCH[1]}"
        fi
        if [[ "$ionice_raw" =~ prio\ ([0-9]+) ]]; then
            ionice_prio="${BASH_REMATCH[1]}"
        fi

        echo "${pid}:${nice_val}:${ionice_class}:${ionice_prio}" >> "$NICE_STATE"

        sudo -n renice -n "$DEPRIORITIZE_NICE" -p "$pid" >/dev/null 2>&1
        sudo -n ionice -c3 -p "$pid" >/dev/null 2>&1
        ((touched++))
    done < <(ps -eo pid,comm --no-headers)
    log "Deprioritized $touched background processes (snapshot saved for exact restore)"
}

restore_priorities() {
    if [[ ! -s "$NICE_STATE" ]]; then
        log "No nice-state snapshot found — nothing to restore (this is normal if turn_on was never run)"
        return
    fi
    local line pid nice_val ionice_class ionice_prio restored=0 failed=0
    local class_num
    while IFS=':' read -r pid nice_val ionice_class ionice_prio; do
        [[ -z "$pid" ]] && continue
        # skip pids that no longer exist
        kill -0 "$pid" 2>/dev/null || continue

        case "$ionice_class" in
            none) class_num=0 ;;
            real-time|realtime) class_num=1 ;;
            best-effort) class_num=2 ;;
            idle) class_num=3 ;;
            *) class_num=2 ;;
        esac

        if sudo -n renice -n "$nice_val" -p "$pid" >/dev/null 2>&1; then
            ((restored++))
        else
            ((failed++))
        fi
        if [[ "$class_num" == "3" ]]; then
            sudo -n ionice -c3 -p "$pid" >/dev/null 2>&1
        else
            sudo -n ionice -c"$class_num" -n"$ionice_prio" -p "$pid" >/dev/null 2>&1
        fi
    done < "$NICE_STATE"
    rm -f "$NICE_STATE"
    if (( failed > 0 )); then
        log "WARNING: restored $restored priorities, but $failed failed (need passwordless sudo?) — check manually"
    else
        log "Restored $restored process priorities to their exact pre-gaming-mode values"
    fi
}

# ── Swappiness ─────────────────────────────────────────────────────────────
# No stash file — always restore to the hardcoded DEFAULT_SWAPPINESS. A
# stash-based approach can silently perpetuate a bad value forever if any
# prior cycle didn't complete cleanly (this bit us once already). If you
# actually run a non-default swappiness normally, change DEFAULT_SWAPPINESS
# above instead of relying on a runtime stash.

lower_swappiness() {
    if sudo -n sysctl -w vm.swappiness="$GAMING_SWAPPINESS" >/dev/null 2>&1; then
        log "swappiness → $GAMING_SWAPPINESS"
    else
        log "couldn't set swappiness (need passwordless sudo) — skipped"
    fi
}

restore_swappiness() {
    if sudo -n sysctl -w vm.swappiness="$DEFAULT_SWAPPINESS" >/dev/null 2>&1; then
        log "swappiness restored → $DEFAULT_SWAPPINESS"
    fi
}

# ── ASUS platform control (asusctl — the correct tool for TUF/ROG boards,
#    talks to the ASUS EC directly; nvidia-settings/nbfc don't apply here) ──

asus_gaming_profile() {
    command -v asusctl >/dev/null 2>&1 || return 0
    asusctl profile set Performance >/dev/null 2>&1
    _asus_verify_profile "Performance"
}

asus_restore_profile() {
    command -v asusctl >/dev/null 2>&1 || return 0
    asusctl profile set Balanced >/dev/null 2>&1
    _asus_verify_profile "Balanced"
}

# Re-reads actual state instead of trusting the exit code — asusctl/EC
# writes can silently no-op, and a silent no-op here is exactly what leaves
# the fan curve + power limits stuck on Performance after you think you've
# turned gaming mode off.
_asus_verify_profile() {
    local expected="$1" actual
    actual=$(asusctl profile get 2>/dev/null | grep -oE 'Performance|Balanced|Quiet' | head -1)
    if [[ "$actual" == "$expected" ]]; then
        log "asusctl profile confirmed → $actual"
    else
        log "WARNING: asked for asusctl profile '$expected' but it reads back as '${actual:-unknown}' — check 'asusctl profile get' manually"
    fi
}

# Same reasoning as _asus_verify_profile: `set` succeeding at the D-Bus call
# level doesn't guarantee the driver actually applied it. Read it back.
_verify_power_profile() {
    local expected="$1" actual
    actual=$(powerprofilesctl get 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        log "Power profile confirmed → $actual"
    else
        log "WARNING: asked for power profile '$expected' but it reads back as '${actual:-unknown}' — check 'powerprofilesctl get' manually"
    fi
}

turn_on() {
    log "Enabling gaming mode"
    [[ -x "$LWE_CTL" ]] && "$LWE_CTL" pause && log "Wallpaper paused"
    [[ -x "$LWE_CTL" ]] && "$LWE_CTL" volume 0 && log "Wallpaper audio muted"

    powerprofilesctl set performance 2>/dev/null
    _verify_power_profile "performance"
    asus_gaming_profile
    lower_swappiness

    for proc in "${AUTO_RESUME_PROCESSES[@]}"; do
        if [[ -n "$(safe_pgrep "$proc")" ]]; then
            safe_pkill -STOP "$proc"
            log "Suspended $proc"
        fi
    done
    for proc in "${MANUAL_START_PROCESSES[@]}"; do
        if [[ -n "$(safe_pgrep "$proc")" ]]; then
            safe_pkill -TERM "$proc"
            log "Terminated $proc"
        fi
    done
    for proc in "${INDEX_DAEMONS[@]}"; do
        if [[ -n "$(safe_pgrep "$proc")" ]]; then
            safe_pkill -TERM "$proc"
            log "Stopped indexing daemon $proc"
        fi
    done

    deprioritize_the_rest

    touch "$FLAG"
    log "Gaming mode ON"
}

turn_off() {
    log "Disabling gaming mode"
    [[ -x "$LWE_CTL" ]] && "$LWE_CTL" resume && log "Wallpaper resumed"
    [[ -x "$VOLUME_CTL" ]] && "$VOLUME_CTL" unmute && log "Wallpaper audio restored"

    powerprofilesctl set balanced 2>/dev/null
    _verify_power_profile "balanced"
    asus_restore_profile
    restore_swappiness
    restore_priorities

    for proc in "${AUTO_RESUME_PROCESSES[@]}"; do
        safe_pkill -CONT "$proc"
        log "Resumed $proc"
    done
    rm -f "$FLAG"
    log "Gaming mode OFF"
}

status() {
    echo "flag file:        $([[ -f "$FLAG" ]] && echo "PRESENT (gaming mode ON)" || echo "absent (gaming mode OFF)")"
    echo "nice-state file:  $([[ -s "$NICE_STATE" ]] && echo "PRESENT — restore_priorities has NOT run since last turn_on (stale if flag is absent)" || echo "absent (clean)")"
    echo "swappiness:       $(cat /proc/sys/vm/swappiness 2>/dev/null) (expect $DEFAULT_SWAPPINESS when off, $GAMING_SWAPPINESS when on)"
    echo "power profile:    $(powerprofilesctl get 2>/dev/null) (expect balanced when off, performance when on)"
    if command -v asusctl >/dev/null 2>&1; then
        echo "asus profile:     $(asusctl profile get 2>/dev/null) (expect Balanced when off, Performance when on)"
    fi
}

case "$1" in
    on)     turn_on  ;;
    off)    turn_off ;;
    status) status   ;;
    *)      echo "Usage: $0 {on|off|status}"; exit 1 ;;
esac