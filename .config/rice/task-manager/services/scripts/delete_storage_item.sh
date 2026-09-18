#!/usr/bin/env bash
# delete_storage_item.sh <type> <path_or_pkgname>
# Outputs: {"success":true} or {"success":false,"error":"..."}
#
# type=dir    -> rm -rf on an absolute path under $HOME or /var/cache/pacman/pkg only
# type=steam  -> rm -rf on an absolute path (raw folder delete -- Steam won't
#                know the game is gone until you verify/repair or remove it
#                from your library manually; this is a disk-space nuke, not
#                a proper uninstall)
# type=pacman -> pacman -Rns <name> via pkexec (needs polkit agent running;
#                niri setups usually have one -- if not, this will just fail
#                and report the error back as JSON)

set -uo pipefail

TYPE="${1:-}"
TARGET="${2:-}"

fail() {
    local msg
    msg=$(echo "$1" | sed 's/"/\\"/g')
    echo "{\"success\":false,\"error\":\"${msg}\"}"
    exit 0
}

ok() {
    echo "{\"success\":true}"
}

[[ -z "$TYPE" || -z "$TARGET" ]] && fail "missing arguments"

case "$TYPE" in
    dir|steam)
        # Safety rails: refuse anything that isn't an absolute path, refuse
        # root/home-root deletes, refuse path traversal tricks.
        [[ "$TARGET" == /* ]] || fail "path must be absolute"
        [[ "$TARGET" == "/" || "$TARGET" == "$HOME" ]] && fail "refusing to delete root or home directory"
        [[ "$TARGET" == *".."* ]] && fail "path traversal not allowed"
        case "$TARGET" in
            "$HOME"/*|/var/cache/pacman/pkg*) ;;
            *) fail "path outside allowed locations" ;;
        esac
        [[ -e "$TARGET" ]] || fail "path does not exist"

        rm -rf -- "$TARGET" 2>/tmp/storage_delete_err
        if [[ $? -eq 0 ]]; then
            ok
        else
            fail "$(cat /tmp/storage_delete_err)"
        fi
        ;;
    pacman)
        # $TARGET is a package name here, not a path.
        [[ "$TARGET" =~ ^[a-zA-Z0-9_.@+-]+$ ]] || fail "invalid package name"
        if command -v pkexec >/dev/null 2>&1; then
            pkexec pacman -Rns --noconfirm "$TARGET" >/tmp/storage_delete_err 2>&1
        else
            sudo -n pacman -Rns --noconfirm "$TARGET" >/tmp/storage_delete_err 2>&1
        fi
        if [[ $? -eq 0 ]]; then
            ok
        else
            fail "$(cat /tmp/storage_delete_err)"
        fi
        ;;
    *)
        fail "unknown type: $TYPE"
        ;;
esac
