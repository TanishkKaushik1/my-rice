#!/usr/bin/env bash
# toggle_startup_app.sh
# Enables or disables an XDG autostart entry by writing/updating a
# Hidden=true|false line in ~/.config/autostart/<id>.desktop.
#
# If the entry only exists system-wide (/etc/xdg/autostart), this copies it
# into the user's autostart dir first (standard XDG override mechanism --
# never edit /etc/xdg/autostart directly, that requires root and affects
# every user on the system).
#
# Usage: toggle_startup_app.sh <id.desktop> <enable|disable>

set -uo pipefail

id="${1:-}"
action="${2:-}"

SYSTEM_DIR="/etc/xdg/autostart"
USER_DIR="$HOME/.config/autostart"

if [[ -z "$id" || -z "$action" ]]; then
    echo '{"success":false,"error":"missing_arguments"}'
    exit 1
fi

if [[ "$action" != "enable" && "$action" != "disable" ]]; then
    echo '{"success":false,"error":"invalid_action"}'
    exit 1
fi

mkdir -p "$USER_DIR"

user_file="${USER_DIR}/${id}"
system_file="${SYSTEM_DIR}/${id}"

# If no user override exists yet, seed one from the system file
if [[ ! -f "$user_file" ]]; then
    if [[ -f "$system_file" ]]; then
        cp "$system_file" "$user_file"
    else
        echo "{\"success\":false,\"id\":\"${id}\",\"error\":\"desktop_file_not_found\"}"
        exit 1
    fi
fi

hidden_value="false"
[[ "$action" == "disable" ]] && hidden_value="true"

if grep -q "^Hidden=" "$user_file"; then
    sed -i "s/^Hidden=.*/Hidden=${hidden_value}/" "$user_file"
else
    echo "Hidden=${hidden_value}" >> "$user_file"
fi

echo "{\"success\":true,\"id\":\"${id}\",\"enabled\":$([[ "$action" == "enable" ]] && echo true || echo false)}"
