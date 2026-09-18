#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# sync-workshop.sh  —  Syncs Steam Workshop Wallpaper Engine content into
#                      your wallpaper switcher directories.
#
# Wallpaper Engine App ID on Steam = 431960
# Workshop items download to:
#   ~/.local/share/Steam/steamapps/workshop/content/431960/<item_id>/
#
# Outputs three directories:
#   Wallpapers/static/   — symlinked image files (for swaybg fallback)
#   Wallpapers/animated/ — symlinked video files (for mpvpaper fallback)
#   Wallpapers/lwe/      — symlinked FOLDERS by numeric ID (for linux-wallpaperengine)
#
# The lwe/ directory is what linux-wallpaperengine uses:
#   linux-wallpaperengine --bg ~/.../Wallpapers/lwe/1234567890
# ─────────────────────────────────────────────────────────────────────────────

WORKSHOP_DIR="${HOME}/.local/share/Steam/steamapps/workshop/content/431960"
STATIC_DIR="${HOME}/.config/rice/Wallpaper-switcher/Wallpapers/static"
VIDEO_DIR="${HOME}/.config/rice/Wallpaper-switcher/Wallpapers/animated"
LWE_DIR="${HOME}/.config/rice/Wallpaper-switcher/Wallpapers/lwe"
THUMB_DIR="${HOME}/.cache/wallpaper-thumbs"

VIDEO_EXTS="mp4 webm avi mkv mov"
STATIC_EXTS="jpg jpeg png webp gif bmp"

mkdir -p "$STATIC_DIR" "$VIDEO_DIR" "$LWE_DIR" "$THUMB_DIR"

log() { echo "[sync-workshop] $*"; }

if [[ ! -d "$WORKSHOP_DIR" ]]; then
    log "ERROR: Workshop directory not found at $WORKSHOP_DIR"
    log "Make sure Wallpaper Engine (App 431960) has downloaded workshop items via Steam."
    exit 1
fi

added_lwe=0
added_legacy=0
removed=0

# ── Step 1: lwe/ — one folder symlink per workshop item ──────────────────────
# linux-wallpaperengine wants the item directory, not an individual file.
# Symlink name = item_id so lwe-ctl.sh can pass it as --bg directly.

for item_dir in "$WORKSHOP_DIR"/*/; do
    [[ -d "$item_dir" ]] || continue
    item_id=$(basename "$item_dir")

    link="${LWE_DIR}/${item_id}"
    if [[ ! -L "$link" ]]; then
        ln -sf "$item_dir" "$link"
        log "[lwe] Added: $item_id"
        ((added_lwe++))
    fi

    # Generate thumbnail from preview.jpg if present and not yet cached
    thumb="${THUMB_DIR}/${item_id}.jpg"
    if [[ ! -f "$thumb" ]]; then
        preview=$(find "$item_dir" -maxdepth 1 -iname "preview.jpg" -o -iname "preview.gif" 2>/dev/null | head -1)
        if [[ -n "$preview" ]]; then
            ln -sf "$preview" "$thumb" 2>/dev/null || true
        fi
    fi
done

# ── Step 2: static/ and animated/ — legacy file symlinks (unchanged) ─────────
# Kept for backward compatibility with any swaybg / mpvpaper fallback paths.

for item_dir in "$WORKSHOP_DIR"/*/; do
    item_id=$(basename "$item_dir")
    found_file=""
    found_ext=""

    for ext in $VIDEO_EXTS; do
        file=$(find "$item_dir" -maxdepth 2 -iname "*.${ext}" | head -1)
        if [[ -n "$file" ]]; then
            found_file="$file"
            found_ext="$ext"
            break
        fi
    done

    if [[ -n "$found_file" ]]; then
        link="$VIDEO_DIR/workshop_${item_id}.${found_ext}"
        if [[ ! -e "$link" ]]; then
            ln -sf "$found_file" "$link"
            log "[animated] Added: workshop_${item_id}.${found_ext}"
            ((added_legacy++))
        fi
        continue
    fi

    for ext in $STATIC_EXTS; do
        file=$(find "$item_dir" -maxdepth 2 -iname "*.${ext}" | head -1)
        if [[ -n "$file" ]]; then
            found_file="$file"
            found_ext="$ext"
            break
        fi
    done

    if [[ -n "$found_file" ]]; then
        link="$STATIC_DIR/workshop_${item_id}.${found_ext}"
        if [[ ! -e "$link" ]]; then
            ln -sf "$found_file" "$link"
            log "[static] Added: workshop_${item_id}.${found_ext}"
            ((added_legacy++))
        fi
    fi
done

# ── Step 3: Remove stale symlinks for deleted workshop items ─────────────────

# lwe/ stale symlinks
for link in "$LWE_DIR"/*/; do
    link="${link%/}"
    [[ -L "$link" ]] || continue
    item_id=$(basename "$link")
    if [[ ! -d "$WORKSHOP_DIR/$item_id" ]]; then
        log "[lwe] Removing deleted item: $item_id"
        rm -f "$link"
        rm -f "${THUMB_DIR}/${item_id}.jpg"
        ((removed++))
    fi
done

# legacy static/animated stale symlinks
for link in "$VIDEO_DIR"/workshop_* "$STATIC_DIR"/workshop_*; do
    [[ -L "$link" ]] || continue
    item_id=$(basename "$link" | sed 's/workshop_//; s/\..*//')
    if [[ ! -d "$WORKSHOP_DIR/$item_id" ]]; then
        log "[legacy] Removing deleted item: $(basename "$link")"
        rm -f "$link"
        ((removed++))
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
log "Sync complete"
log "  lwe/:     +${added_lwe} folders symlinked"
log "  legacy:   +${added_legacy} file symlinks"
log "  removed:  ${removed}"
log ""
log "LWE wallpapers available in: $LWE_DIR"
log "Set one with: lwe-ctl.sh set <item_id>"