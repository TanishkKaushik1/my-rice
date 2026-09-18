#!/usr/bin/env bash
# get_gpu_usage.sh
# Outputs current NVIDIA GPU usage as single-line JSON:
#   {"utilization_percent":<int>,"mem_used_mb":<int>,"mem_total_mb":<int>,"mem_percent":<float>,"temp_c":<int>}
#
# Requires nvidia-smi (part of the proprietary driver). If it's missing or
# the query fails (e.g. GPU asleep, driver issue), outputs a zeroed object
# with "available":false so the UI can grey out the GPU card instead of
# crashing on a parse error.

set -uo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo '{"available":false,"utilization_percent":0,"mem_used_mb":0,"mem_total_mb":0,"mem_percent":0,"temp_c":0}'
    exit 0
fi

line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null | head -n1)

if [[ -z "$line" ]]; then
    echo '{"available":false,"utilization_percent":0,"mem_used_mb":0,"mem_total_mb":0,"mem_percent":0,"temp_c":0}'
    exit 0
fi

util=$(echo "$line" | awk -F',' '{gsub(/ /,"",$1); print $1}')
mem_used=$(echo "$line" | awk -F',' '{gsub(/ /,"",$2); print $2}')
mem_total=$(echo "$line" | awk -F',' '{gsub(/ /,"",$3); print $3}')
temp=$(echo "$line" | awk -F',' '{gsub(/ /,"",$4); print $4}')

mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN {
    if (total > 0) printf "%.1f", (used / total) * 100
    else print "0"
}')

echo "{\"available\":true,\"utilization_percent\":${util},\"mem_used_mb\":${mem_used},\"mem_total_mb\":${mem_total},\"mem_percent\":${mem_percent},\"temp_c\":${temp}}"
