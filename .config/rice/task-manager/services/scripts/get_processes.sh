#!/usr/bin/env bash
# get_processes.sh
# Outputs a JSON array of running processes, sorted by CPU usage (descending),
# suitable for feeding directly into a QML ListModel.
#
# Optimized to use purely native bash string manipulation.
# Zero subshells (awk/sed) are spawned inside the loop.

set -uo pipefail

# Grab processes, explicitly sorting by CPU usage
ps_output=$(ps -eo pid,%cpu,%mem,rss,user,comm --sort=-%cpu --no-headers)

json_entries=()

# The `read` command natively splits by whitespace.
# Providing 6 variables means the 6th variable ('name') automatically absorbs
# any remaining words, perfectly handling process names with spaces.
while read -r pid cpu mem_percent rss_kb user name; do
    [[ -z "$pid" ]] && continue

    # ---- Validation guards ----
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ "$rss_kb" =~ ^[0-9]+$ ]] || continue
    [[ "$cpu" =~ ^[0-9]+(\.[0-9]+)?$ ]] || continue
    [[ "$mem_percent" =~ ^[0-9]+(\.[0-9]+)?$ ]] || continue

    # Fallback name if comm was genuinely empty
    [[ -z "$name" ]] && name="(unknown)"

    mem_mb=$(( rss_kb / 1024 ))

    # Native bash parameter expansion replaces `sed 's/"/\\"/g'` incredibly fast
    safe_name="${name//\"/\\\"}"

    json_entries+=("{\"pid\":${pid},\"name\":\"${safe_name}\",\"cpu\":${cpu},\"mem_mb\":${mem_mb},\"mem_percent\":${mem_percent},\"user\":\"${user}\"}")
done <<< "$ps_output"

IFS=,
echo "[${json_entries[*]}]"