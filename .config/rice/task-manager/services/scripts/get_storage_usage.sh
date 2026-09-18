#!/usr/bin/env bash
# get_storage_usage.sh
# Outputs one JSON object:
# {
#   "disk": {"total":<bytes>,"used":<bytes>,"free":<bytes>,"mount":"/"},
#   "items": [
#     {"id":"...","name":"...","size":<bytes>,"type":"dir|pacman|steam",
#      "path":"...","deletable":true,"detail":"..."}
#   ]
# }
#
# "type" tells the UI/delete script how to remove it:
#   dir    -> rm -rf <path>
#   pacman -> pacman -Rns <name> (needs sudo/polkit, handled by delete script)
#   steam  -> rm -rf <path> (raw folder delete, not a real Steam uninstall)
#
# Scans (edit the arrays below to tune what shows up):
#   - Common cache/data directories under $HOME
#   - Installed pacman packages (includes AUR/yay packages -- yay just wraps
#     pacman, so `pacman -Qi` already covers everything yay installed)
#   - Steam library folders (default path + any extra libraryfolders.vdf entries)

set -uo pipefail

MOUNT="/"

# ---------- Disk totals (for the pie chart) ----------
disk_line=$(df -B1 --output=size,used,avail "$MOUNT" | tail -n1)
disk_total=$(echo "$disk_line" | awk '{print $1}')
disk_used=$(echo "$disk_line" | awk '{print $2}')
disk_free=$(echo "$disk_line" | awk '{print $3}')

items=()

add_item() {
    # $1=id $2=name $3=size $4=type $5=path $6=deletable $7=detail
    local safe_name safe_detail safe_path
    safe_name=$(echo "$2" | sed 's/"/\\"/g')
    safe_detail=$(echo "$7" | sed 's/"/\\"/g')
    safe_path=$(echo "$5" | sed 's/"/\\"/g')
    items+=("{\"id\":\"${1}\",\"name\":\"${safe_name}\",\"size\":${3},\"type\":\"${4}\",\"path\":\"${safe_path}\",\"deletable\":${6},\"detail\":\"${safe_detail}\"}")
}

# ---------- Common directories ----------
DIR_CANDIDATES=(
    "$HOME/.cache"
    "$HOME/.local/share"
    "$HOME/.config"
    "$HOME/Downloads"
    "$HOME/.var/app"
    "/var/cache/pacman/pkg"
)

for d in "${DIR_CANDIDATES[@]}"; do
    [[ -d "$d" ]] || continue
    size=$(du -sb "$d" 2>/dev/null | cut -f1)
    [[ -z "$size" ]] && continue
    id=$(echo "$d" | sed 's/[^a-zA-Z0-9]/_/g')
    deletable="true"
    # Don't allow blind rm -rf on the whole ~/.config -- too dangerous.
    [[ "$d" == "$HOME/.config" ]] && deletable="false"
    add_item "dir_${id}" "$d" "$size" "dir" "$d" "$deletable" "Directory"
done

# ---------- Pacman/yay packages (installed size, top offenders) ----------
if command -v pacman >/dev/null 2>&1; then
    while IFS='|' read -r name size_kib; do
        [[ -z "$name" ]] && continue
        size_bytes=$((size_kib * 1024))
        add_item "pkg_${name}" "$name" "$size_bytes" "pacman" "$name" "true" "Installed package"
    done < <(pacman -Qi 2>/dev/null | awk -F': ' '
        /^Name/ {name=$2}
        /^Installed Size/ {
            split($2, a, " ")
            val=a[1]; unit=a[2]
            if (unit == "MiB") val = val * 1024
            else if (unit == "GiB") val = val * 1024 * 1024
            else if (unit == "KiB") val = val
            printf "%s|%d\n", name, val
        }
    ')
fi

# ---------- Steam library ----------
STEAM_ROOTS=(
    "$HOME/.local/share/Steam/steamapps/common"
    "$HOME/.steam/steam/steamapps/common"
)
# Also check libraryfolders.vdf for additional library paths
VDF="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
if [[ -f "$VDF" ]]; then
    while read -r extra_path; do
        [[ -n "$extra_path" ]] && STEAM_ROOTS+=("${extra_path}/steamapps/common")
    done < <(grep -oP '"path"\s*"\K[^"]+' "$VDF" 2>/dev/null)
fi

declare -A steam_seen
for root in "${STEAM_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    for game_dir in "$root"/*/; do
        [[ -d "$game_dir" ]] || continue
        game_name=$(basename "$game_dir")
        [[ -n "${steam_seen[$game_name]:-}" ]] && continue
        steam_seen[$game_name]=1
        size=$(du -sb "$game_dir" 2>/dev/null | cut -f1)
        [[ -z "$size" ]] && continue
        id=$(echo "$game_name" | sed 's/[^a-zA-Z0-9]/_/g')
        add_item "steam_${id}" "$game_name" "$size" "steam" "${game_dir%/}" "true" "Steam game"
    done
done

# ---------- Assemble JSON ----------
IFS=,
echo "{\"disk\":{\"total\":${disk_total},\"used\":${disk_used},\"free\":${disk_free},\"mount\":\"${MOUNT}\"},\"items\":[${items[*]}]}"
