#!/usr/bin/env bash
set -u

# Toggle the Wallpaper-Switcher quickshell instance tied to the Wallpaper-Switcher folder
WP_DIR="$HOME/.config/rice/Wallpaper-Switcher"

# Try to find a running 'qs -p <WP_DIR>' or quickshell instance pointing at the directory
found_pids="$(pgrep -f "qs -p $WP_DIR" || true)"
if [ -z "$found_pids" ]; then
  found_pids="$(pgrep -f "quickshell.*$WP_DIR" || true)"
fi

if [ -n "$found_pids" ]; then
  # Close the running instance(s)
  pkill -f "$WP_DIR" || true
  exit 0
fi

# Not running — launch in background so niri doesn't block
qs -p "$WP_DIR" &
