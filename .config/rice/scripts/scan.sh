#!/usr/bin/env bash
# scan-paths.sh — find hardcoded user-specific paths in your dotfiles
DIR="${1:-.}"
USER="${2:-$USER}"

echo "== Absolute /home/$USER paths =="
grep -rn "/home/$USER" "$DIR" --include='*' -I 2>/dev/null

echo "== Any /home/<user> paths (in case of other machines) =="
grep -rnE "/home/[a-zA-Z0-9_-]+" "$DIR" -I 2>/dev/null | grep -v "/home/$USER"

echo "== References to \$HOME already (good, skip these) =="
grep -rln '\$HOME' "$DIR" --include='*' -I 2>/dev/null

echo "== Hardcoded XDG-style paths (config/cache/local) =="
grep -rnE "/home/$USER/\.(config|cache|local)" "$DIR" -I 2>/dev/null