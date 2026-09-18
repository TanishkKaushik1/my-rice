#!/usr/bin/env bash
# Restore last applied Wallpaper Engine wallpaper after login.
# Called by systemd user service: restore-wallpaper.service

LAST_FILE="$HOME/.config/rice/Wallpaper-Switcher/last_wallpaper.json"
LWE="/usr/bin/linux-wallpaperengine"
ASSETS="$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
SCREEN="eDP-1"
LOG="/tmp/lwe.log"

# Wait for Niri or Hyprland to be ready (Wayland compositor must be up)
for i in $(seq 1 20); do
    if pgrep -i "hyprland" >/dev/null 2>&1 || niri msg version >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Check dependencies
if [ ! -x "$LWE" ]; then
    echo "restore-wallpaper: lwe not found at $LWE" >> /tmp/restore-wallpaper.log
    exit 1
fi

if [ ! -f "$LAST_FILE" ]; then
    echo "restore-wallpaper: no last_wallpaper.json found" >> /tmp/restore-wallpaper.log
    exit 0
fi

# Parse JSON — extract wallpaperPath
WALLPAPER_PATH=$(python3 -c "
import json, sys
d = json.load(open('$LAST_FILE'))
print(d.get('wallpaperPath',''))
" 2>/dev/null)

if [ -z "$WALLPAPER_PATH" ] || [ ! -d "$WALLPAPER_PATH" ]; then
    echo "restore-wallpaper: path invalid: $WALLPAPER_PATH" >> /tmp/restore-wallpaper.log
    exit 1
fi

echo "restore-wallpaper: applying $WALLPAPER_PATH" >> /tmp/restore-wallpaper.log

# Kill any existing lwe first, then launch — all under one lock so this
# never races with WallpaperService.qml's own kill+launch cycle
(
  flock -x 9
  pkill -f "[l]inux-wallpaperengine" 2>/dev/null || true
  i=0
  while pgrep -f "[l]inux-wallpaperengine" > /dev/null 2>&1 && [ $i -lt 20 ]; do
      sleep 0.1; i=$((i+1))
  done
  pkill -9 -f "[l]inux-wallpaperengine" 2>/dev/null || true

  __GL_THREADED_OPTIMIZATIONS=0 __GL_YIELD=USLEEP \
      "$LWE" --assets-dir "$ASSETS" --screen-root "$SCREEN" \
      --mpv-hwdec=nvdec --scaling fill --bg "$WALLPAPER_PATH" \
      >> "$LOG" 2>&1 &
  echo "restore-wallpaper: launched OK (pid $!)" >> /tmp/restore-wallpaper.log
) 9>/tmp/.lwe-launch.lock