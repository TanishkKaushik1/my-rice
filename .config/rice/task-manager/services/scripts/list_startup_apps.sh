#!/usr/bin/env bash
# list_startup_apps.sh
# Discovery-only. Combines two sources into one JSON array:
#   1. XDG autostart (.desktop files)      -> source: "xdg"
#   2. niri spawn-at-startup lines          -> source: "niri"
#
# niri entries are NOT toggleable (there's no runtime API to disable a
# spawn-at-startup line -- that would mean rewriting config.kdl, which we
# deliberately don't do here). They're listed with "enabled":true and
# "toggleable":false so the UI can grey out the switch for them.
#
# BLOCKLIST: quickshell UI spawns (bar, launcher, customization panel, etc.)
# are excluded because they're already managed by a separate autostart-UI
# tool. Edit NIRI_BLOCKLIST below to add/remove patterns (case-insensitive
# substring match against the full spawn command).

set -uo pipefail

SYSTEM_DIR="/etc/xdg/autostart"
USER_DIR="$HOME/.config/autostart"
NIRI_CONFIG="$HOME/.config/niri/config.kdl"

# Any spawn-at-startup line whose full command contains one of these
# (case-insensitive) is skipped -- these are UI shells, not daemons.
NIRI_BLOCKLIST=(
    "quickshell"
)

declare -A seen
entries=()

get_field() {
    grep -m1 "^${2}=" "$1" 2>/dev/null | head -n1 | cut -d'=' -f2- | sed 's/[[:space:]]*$//'
}

is_enabled() {
    local file="$1"
    local hidden
    hidden=$(get_field "$file" "Hidden")
    [[ "$hidden" == "true" ]] && { echo "false"; return; }
    local gnome_enabled
    gnome_enabled=$(get_field "$file" "X-GNOME-Autostart-enabled")
    [[ "$gnome_enabled" == "false" ]] && { echo "false"; return; }
    echo "true"
}

process_xdg_dir() {
    local dir="$1"
    local source_label="$2"
    [[ -d "$dir" ]] || return

    for f in "$dir"/*.desktop; do
        [[ -f "$f" ]] || continue
        local id
        id=$(basename "$f")
        [[ -n "${seen[$id]:-}" ]] && continue
        seen[$id]=1

        local name comment enabled
        name=$(get_field "$f" "Name")
        [[ -z "$name" ]] && name="$id"
        comment=$(get_field "$f" "Comment")
        enabled=$(is_enabled "$f")

        local safe_name safe_comment
        safe_name=$(echo "$name" | sed 's/"/\\"/g')
        safe_comment=$(echo "$comment" | sed 's/"/\\"/g')

        entries+=("{\"id\":\"${id}\",\"name\":\"${safe_name}\",\"comment\":\"${safe_comment}\",\"enabled\":${enabled},\"source\":\"xdg\",\"toggleable\":true}")
    done
}

is_blocked() {
    local cmd="$1"
    local pattern
    for pattern in "${NIRI_BLOCKLIST[@]}"; do
        if echo "$cmd" | grep -qi "$pattern"; then
            return 0
        fi
    done
    return 1
}

process_niri_config() {
    [[ -f "$NIRI_CONFIG" ]] || return
    local idx=0

    # Match lines like: spawn-at-startup "foo" "bar" "baz"
    while IFS= read -r line; do
        # Strip leading whitespace and the "spawn-at-startup" keyword
        local rest="${line#*spawn-at-startup}"

        # Extract every quoted token on the line, in order
        local -a tokens=()
        while [[ "$rest" =~ \"([^\"]*)\"(.*) ]]; do
            tokens+=("${BASH_REMATCH[1]}")
            rest="${BASH_REMATCH[2]}"
        done
        [[ ${#tokens[@]} -eq 0 ]] && continue

        local full_cmd="${tokens[*]}"
        is_blocked "$full_cmd" && continue

        idx=$((idx + 1))
        local id="niri-spawn-${idx}"

        # Display name: basename of first token (strip path), or the
        # basename of the second token if first is an interpreter (bash/sh)
        local first="${tokens[0]}"
        local disp="$first"
        if [[ "$first" == "bash" || "$first" == "sh" ]] && [[ ${#tokens[@]} -gt 1 ]]; then
            disp="${tokens[1]}"
        fi
        disp=$(basename "$disp")

        local safe_name safe_comment
        safe_name=$(echo "$disp" | sed 's/"/\\"/g')
        safe_comment=$(echo "$full_cmd" | sed 's/"/\\"/g')

        entries+=("{\"id\":\"${id}\",\"name\":\"${safe_name}\",\"comment\":\"${safe_comment}\",\"enabled\":true,\"source\":\"niri\",\"toggleable\":false}")
    done < <(grep -E '^\s*spawn-at-startup\s' "$NIRI_CONFIG")
}

process_xdg_dir "$USER_DIR" "xdg"
process_xdg_dir "$SYSTEM_DIR" "xdg"
process_niri_config

IFS=,
echo "[${entries[*]}]"