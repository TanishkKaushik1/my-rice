#!/usr/bin/env bash
# get_gpu_processes.sh
# Outputs JSON array of processes currently using GPU memory:
#   [{"pid":<int>,"name":"...","mem_mb":<int>}]
#
# NOTE: NVIDIA doesn't expose true per-process GPU-core utilization (only
# total GPU util as a whole) -- --query-compute-apps only gives VRAM usage
# per process. That's still useful for "what's eating my VRAM" but it's not
# a per-process utilization percentage like CPU has.

set -uo pipefail

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo '[]'
    exit 0
fi

declare -A seen
entries=()

collect() {
    # $1 = nvidia-smi query flag (compute-apps or graphics-apps)
    while IFS=',' read -r pid mem; do
        pid=$(echo "$pid" | tr -d ' ')
        mem=$(echo "$mem" | tr -d ' ')
        [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]] && continue
        [[ -n "${seen[$pid]:-}" ]] && continue
        seen[$pid]=1

        name="unknown"
        if [[ -r "/proc/${pid}/comm" ]]; then
            name=$(cat "/proc/${pid}/comm" 2>/dev/null)
        fi
        safe_name=$(echo "$name" | sed 's/"/\\"/g')

        entries+=("{\"pid\":${pid},\"name\":\"${safe_name}\",\"mem_mb\":${mem:-0}}")
    done < <(nvidia-smi --query-${1}=pid,used_memory --format=csv,noheader,nounits 2>/dev/null)
}

collect "compute-apps"
collect "graphics-apps"

IFS=,
echo "[${entries[*]}]"
