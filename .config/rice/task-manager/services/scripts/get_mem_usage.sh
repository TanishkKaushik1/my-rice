#!/usr/bin/env bash
# get_mem_usage.sh
# Outputs current RAM usage as a single-line JSON object, parsed from /proc/meminfo.
# Fields:
#   total_kb / used_kb / available_kb / free_kb  -> raw kB values
#   total_mb / used_mb / available_mb            -> convenience MB values (integers)
#   percent                                      -> used / total * 100, 1 decimal place

set -euo pipefail

meminfo="/proc/meminfo"

get_val() {
    # $1 = key name as it appears in /proc/meminfo (e.g. MemTotal)
    awk -v key="$1" '$1 == key":" { print $2; exit }' "$meminfo"
}

total_kb=$(get_val "MemTotal")
free_kb=$(get_val "MemFree")
available_kb=$(get_val "MemAvailable")
buffers_kb=$(get_val "Buffers")
cached_kb=$(get_val "Cached")

# "Used" the way Windows Task Manager / htop define it:
# total - available (available already accounts for reclaimable cache/buffers)
used_kb=$(( total_kb - available_kb ))

total_mb=$(( total_kb / 1024 ))
used_mb=$(( used_kb / 1024 ))
available_mb=$(( available_kb / 1024 ))
free_mb=$(( free_kb / 1024 ))

percent=$(awk -v used="$used_kb" -v total="$total_kb" 'BEGIN { printf "%.1f", (used / total) * 100 }')

cat <<EOF
{"total_kb":${total_kb},"used_kb":${used_kb},"available_kb":${available_kb},"free_kb":${free_kb},"total_mb":${total_mb},"used_mb":${used_mb},"available_mb":${available_mb},"free_mb":${free_mb},"percent":${percent}}
EOF