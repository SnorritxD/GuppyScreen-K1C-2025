#!/bin/sh
# GuppyScreen K1C 2025/2026 - public fail-safe uninstaller
#
# Safety rules:
#   - Only root may run this uninstaller.
#   - Only the known K1C 2025/2026 hardware layout is accepted.
#   - Ambiguous or unexpected states are rejected before changes.
#   - A valid pre-install backup is required.
#   - A second emergency backup of the current state is created before changes.
#   - guppyconfig.json is NEVER copied, removed or replaced.
#   - Restore is verified before the uninstall is declared successful.
#   - Any failure after modifications triggers automatic rollback.
#   - No reboot is performed.

set -u
umask 022

INSTALL_DIR="/usr/data/guppyscreen"
INIT_DIR="/usr/apps/etc/init.d"
BACKUP_ROOT="/usr/data/guppyscreen-k1c-backup"
EMERGENCY_ROOT="/usr/data/guppyscreen-uninstall-backup"

SERVICE="S57guppy_service"
CREALITY_SERVICE="CS60gui_service"
DISABLED_CREALITY="disabled.$CREALITY_SERVICE"

# ORIGINAL CREALITY SERVICE SAFETY RULE:
# CS60gui_service and disabled.CS60gui_service are never removed.
# They may only be renamed or copied when restoring state.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_BACKUP=""
EMERGENCY_BACKUP=""
ROLLBACK_NEEDED=0
ORIGINAL_PROCESS_COUNT=0

fail()
{
    echo >&2
    echo "ERROR: $*" >&2
    echo >&2
    exit 1
}

count_guppy()
{
    pgrep -f "$INSTALL_DIR/guppyscreen" 2>/dev/null | wc -l
}

stop_guppy()
{
    if [ -x "$INIT_DIR/$SERVICE" ]; then
        "$INIT_DIR/$SERVICE" stop >/dev/null 2>&1 || true
    fi
    sleep 1
}

backup_current()
{
    B="$1"

    mkdir -p "$B" || return 1
    echo "GuppyScreen K1C uninstall emergency backup" > "$B/README" || return 1

    if [ -f "$INSTALL_DIR/guppyscreen" ]; then
        touch "$B/had_binary"
        cp -p "$INSTALL_DIR/guppyscreen" "$B/guppyscreen" || return 1
    fi

    if [ -d "$INSTALL_DIR/assets" ]; then
        touch "$B/had_assets"
        cp -a "$INSTALL_DIR/assets" "$B/assets" || return 1
    fi

    if [ -d "$INSTALL_DIR/themes" ]; then
        touch "$B/had_themes"
        cp -a "$INSTALL_DIR/themes" "$B/themes" || return 1
    fi

    if [ -f "$INIT_DIR/$SERVICE" ]; then
        touch "$B/had_service"
        cp -p "$INIT_DIR/$SERVICE" "$B/$SERVICE" || return 1
    fi

    if [ -f "$INIT_DIR/$CREALITY_SERVICE" ]; then
        touch "$B/had_creality_active"
        cp -p "$INIT_DIR/$CREALITY_SERVICE" "$B/$CREALITY_SERVICE" || return 1
    fi

    if [ -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
        touch "$B/had_creality_disabled"
        cp -p "$INIT_DIR/$DISABLED_CREALITY" "$B/$DISABLED_CREALITY" || return 1
    fi

    return 0
}

verify_backup()
{
    B="$1"

    [ -f "$B/README" ] || return 1

    if [ -f "$B/had_binary" ]; then
        [ -f "$B/guppyscreen" ] || return 1
    fi

    if [ -f "$B/had_assets" ]; then
        [ -d "$B/assets" ] || return 1
    fi

    if [ -f "$B/had_themes" ]; then
        [ -d "$B/themes" ] || return 1
    fi

    if [ -f "$B/had_service" ]; then
        [ -f "$B/$SERVICE" ] || return 1
    fi

    if [ -f "$B/had_creality_active" ]; then
        [ -f "$B/$CREALITY_SERVICE" ] || return 1
    fi

    if [ -f "$B/had_creality_disabled" ]; then
        [ -f "$B/$DISABLED_CREALITY" ] || return 1
    fi

    return 0
}

verify_source_backup()
{
    B="$1"

    verify_backup "$B" || return 1

    # A valid pre-install backup must contain the Creality service that
    # existed before installation. It may have been active or already disabled.
    if [ -f "$B/had_creality_active" ]; then
        [ -f "$B/$CREALITY_SERVICE" ] || return 1
    elif [ -f "$B/had_creality_disabled" ]; then
        [ -f "$B/$DISABLED_CREALITY" ] || return 1
    else
        return 1
    fi

    # The installer stores this exact marker in every pre-install backup.
    grep -q "GuppyScreen K1C installer backup" "$B/README" 2>/dev/null || return 1

    return 0
}

restore_from_backup()
{
    B="$1"

    set +e

    # Stop anything GuppyScreen-related before restoring files.
    if [ -x "$INIT_DIR/$SERVICE" ]; then
        "$INIT_DIR/$SERVICE" stop >/dev/null 2>&1 || true
    fi
    sleep 1

    # Guppy startup service is our own file and may be removed during restore.
    rm -f "$INIT_DIR/$SERVICE"

    # IMPORTANT SAFETY RULE:
    # Never rm/unlink either original Creality service.
    # Restore the exact Creality state using rename/copy only.
    if [ -f "$B/had_creality_active" ]; then
        if [ -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
            mv "$INIT_DIR/$DISABLED_CREALITY" "$INIT_DIR/$CREALITY_SERVICE" || true
        fi
        if [ ! -f "$INIT_DIR/$CREALITY_SERVICE" ] && [ -f "$B/$CREALITY_SERVICE" ]; then
            cp -p "$B/$CREALITY_SERVICE" "$INIT_DIR/$CREALITY_SERVICE" || true
        fi
        chmod 755 "$INIT_DIR/$CREALITY_SERVICE" 2>/dev/null || true
    elif [ -f "$B/had_creality_disabled" ]; then
        if [ -f "$INIT_DIR/$CREALITY_SERVICE" ]; then
            mv "$INIT_DIR/$CREALITY_SERVICE" "$INIT_DIR/$DISABLED_CREALITY" || true
        fi
        if [ ! -f "$INIT_DIR/$DISABLED_CREALITY" ] && [ -f "$B/$DISABLED_CREALITY" ]; then
            cp -p "$B/$DISABLED_CREALITY" "$INIT_DIR/$DISABLED_CREALITY" || true
        fi
        chmod 755 "$INIT_DIR/$DISABLED_CREALITY" 2>/dev/null || true
    fi

    if [ -f "$B/had_binary" ]; then
        mkdir -p "$INSTALL_DIR"
        cp -p "$B/guppyscreen" "$INSTALL_DIR/guppyscreen" || true
        chmod 755 "$INSTALL_DIR/guppyscreen" 2>/dev/null || true
    else
        rm -f "$INSTALL_DIR/guppyscreen"
    fi

    if [ -f "$B/had_assets" ]; then
        rm -rf "$INSTALL_DIR/assets"
        cp -a "$B/assets" "$INSTALL_DIR/assets" || true
    else
        rm -rf "$INSTALL_DIR/assets"
    fi

    if [ -f "$B/had_themes" ]; then
        rm -rf "$INSTALL_DIR/themes"
        cp -a "$B/themes" "$INSTALL_DIR/themes" || true
    else
        rm -rf "$INSTALL_DIR/themes"
    fi

    if [ -f "$B/had_service" ]; then
        cp -p "$B/$SERVICE" "$INIT_DIR/$SERVICE" || true
        chmod 755 "$INIT_DIR/$SERVICE" 2>/dev/null || true
    fi
}

verify_restored()
{
    B="$1"
    OK=1

    # Service state
    if [ -f "$B/had_service" ]; then
        cmp -s "$B/$SERVICE" "$INIT_DIR/$SERVICE" || OK=0
    else
        [ ! -e "$INIT_DIR/$SERVICE" ] || OK=0
    fi

    # Verify the exact Creality service state represented by the backup.
    if [ -f "$B/had_creality_active" ]; then
        cmp -s "$B/$CREALITY_SERVICE" "$INIT_DIR/$CREALITY_SERVICE" || OK=0
        [ ! -e "$INIT_DIR/$DISABLED_CREALITY" ] || OK=0
    elif [ -f "$B/had_creality_disabled" ]; then
        cmp -s "$B/$DISABLED_CREALITY" "$INIT_DIR/$DISABLED_CREALITY" || OK=0
        [ ! -e "$INIT_DIR/$CREALITY_SERVICE" ] || OK=0
    else
        OK=0
    fi

    # Guppy files
    if [ -f "$B/had_binary" ]; then
        cmp -s "$B/guppyscreen" "$INSTALL_DIR/guppyscreen" || OK=0
    else
        [ ! -e "$INSTALL_DIR/guppyscreen" ] || OK=0
    fi

    if [ -f "$B/had_assets" ]; then
        diff -qr "$B/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1 || OK=0
    else
        [ ! -e "$INSTALL_DIR/assets" ] || OK=0
    fi

    if [ -f "$B/had_themes" ]; then
        diff -qr "$B/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1 || OK=0
    else
        [ ! -e "$INSTALL_DIR/themes" ] || OK=0
    fi

    [ "$(count_guppy)" = "0" ] || OK=0

    [ "$OK" = "1" ]
}

rollback()
{
    set +e

    echo
    echo "============================================================"
    echo "             AUTOMATIC UNINSTALL ROLLBACK"
    echo "============================================================"
    echo

    if [ -n "$EMERGENCY_BACKUP" ] && [ -d "$EMERGENCY_BACKUP" ]; then
        echo "[ROLLBACK] Restoring the state from immediately before uninstall..."
        restore_from_backup "$EMERGENCY_BACKUP"

        if verify_restored "$EMERGENCY_BACKUP"; then
            echo "[ROLLBACK] Previous state restored and verified."
        else
            echo "[ROLLBACK] WARNING: emergency restore verification FAILED." >&2
            echo "[ROLLBACK] Do NOT reboot or retry blindly." >&2
            echo "[ROLLBACK] Emergency backup: $EMERGENCY_BACKUP" >&2
        fi
    else
        echo "[ROLLBACK] No emergency backup is available." >&2
        echo "[ROLLBACK] Do NOT reboot or retry blindly." >&2
    fi

    echo "[ROLLBACK] guppyconfig.json was never touched."
    exit 1
}

trap 'if [ "$ROLLBACK_NEEDED" = "1" ]; then rollback; fi' EXIT INT TERM

echo
echo "============================================================"
echo "      GuppyScreen K1C 2025/2026 Uninstaller"
echo "             FAIL-SAFE + RESTORE"
echo "============================================================"
echo

echo "[1/8] Preflight checks..."

[ "$(id -u)" = "0" ] || fail "Run this uninstaller as root."
[ -d "/usr/data" ] || fail "/usr/data does not exist."
[ -d "$INIT_DIR" ] || fail "$INIT_DIR does not exist."

for cmd in uname cmp diff pgrep wc cp mv rm mkdir chmod date sleep grep touch; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Required command not available: $cmd"
done

ARCH="$(uname -m 2>/dev/null || true)"
echo "Architecture: $ARCH"
[ "$ARCH" = "mips" ] || fail "Unsupported CPU architecture: $ARCH (expected mips)."

[ -e /dev/fb1 ] || fail "/dev/fb1 not found. Unsupported K1C hardware."
[ -e /dev/input/event1 ] || fail "/dev/input/event1 not found. Touchscreen missing."

if [ -r /sys/class/graphics/fb1/name ]; then
    FB_NAME="$(cat /sys/class/graphics/fb1/name 2>/dev/null || true)"
    echo "Framebuffer: $FB_NAME"
    [ "$FB_NAME" = "jzfb" ] || fail "Unexpected framebuffer on fb1: $FB_NAME"
fi

if [ -r /sys/class/input/event1/device/name ]; then
    TOUCH_NAME="$(cat /sys/class/input/event1/device/name 2>/dev/null || true)"
    echo "Touchscreen: $TOUCH_NAME"
    [ "$TOUCH_NAME" = "goodix-ts" ] || fail "Unexpected touchscreen on event1: $TOUCH_NAME"
fi

echo "Preflight checks OK."

echo
echo "[2/8] Checking GuppyScreen installation state..."

ACTIVE=0
DISABLED=0
SERVICE_PRESENT=0
BINARY_PRESENT=0
ASSETS_PRESENT=0
THEMES_PRESENT=0

[ -f "$INIT_DIR/$CREALITY_SERVICE" ] && ACTIVE=1
[ -f "$INIT_DIR/$DISABLED_CREALITY" ] && DISABLED=1
[ -f "$INIT_DIR/$SERVICE" ] && SERVICE_PRESENT=1
[ -f "$INSTALL_DIR/guppyscreen" ] && BINARY_PRESENT=1
[ -d "$INSTALL_DIR/assets" ] && ASSETS_PRESENT=1
[ -d "$INSTALL_DIR/themes" ] && THEMES_PRESENT=1

if [ "$ACTIVE" = "1" ] && [ "$DISABLED" = "1" ]; then
    fail "Both $CREALITY_SERVICE and $DISABLED_CREALITY exist. State is ambiguous. No changes made."
fi

if [ "$ACTIVE" = "1" ]; then
    fail "$CREALITY_SERVICE is active. Refusing to uninstall because GuppyScreen may not be the active GUI."
fi

if [ "$DISABLED" != "1" ]; then
    fail "$DISABLED_CREALITY is missing. Refusing to guess how the stock GUI was disabled."
fi

if [ "$SERVICE_PRESENT" = "0" ] && [ "$BINARY_PRESENT" = "0" ] &&
   [ "$ASSETS_PRESENT" = "0" ] && [ "$THEMES_PRESENT" = "0" ]; then
    fail "No GuppyScreen installation was detected."
fi

COUNT="$(count_guppy)"
echo "GuppyScreen process count: $COUNT"
ORIGINAL_PROCESS_COUNT="$COUNT"

[ "$COUNT" -le 1 ] || fail "More than one GuppyScreen process is running. Refusing to guess which one to stop."

echo "Installation state is recognized."

echo
echo "[3/8] Finding a verified pre-install backup..."

[ -d "$BACKUP_ROOT" ] || fail "No GuppyScreen backup directory exists: $BACKUP_ROOT"

LATEST=""
for D in "$BACKUP_ROOT"/*; do
    [ -d "$D" ] || continue
    case "$D" in
        "$BACKUP_ROOT"/20*) ;;
        *) continue ;;
    esac

    if verify_source_backup "$D"; then
        LATEST="$D"
    fi
done

[ -n "$LATEST" ] || fail "No valid pre-install backup was found. Nothing was changed."

SOURCE_BACKUP="$LATEST"
echo "Using verified pre-install backup: $SOURCE_BACKUP"

echo
echo "[4/8] Creating emergency backup of the current state..."

STAMP="$(date +%Y%m%d-%H%M%S)"
EMERGENCY_BACKUP="$EMERGENCY_ROOT/$STAMP"
[ ! -e "$EMERGENCY_BACKUP" ] || fail "Emergency backup directory already exists: $EMERGENCY_BACKUP"

backup_current "$EMERGENCY_BACKUP" || fail "Could not create emergency backup."
verify_backup "$EMERGENCY_BACKUP" || fail "Emergency backup verification failed."

echo "Emergency backup verified: $EMERGENCY_BACKUP"
ROLLBACK_NEEDED=1

echo
echo "[5/8] Stopping GuppyScreen..."

stop_guppy
[ "$(count_guppy)" = "0" ] || fail "GuppyScreen did not stop safely."

echo
echo "[6/8] Restoring original pre-install state..."

restore_from_backup "$SOURCE_BACKUP"

# The stock Creality GUI service must be active again.
[ -f "$INIT_DIR/$CREALITY_SERVICE" ] || fail "$CREALITY_SERVICE was not restored."
[ ! -e "$INIT_DIR/$DISABLED_CREALITY" ] || fail "$DISABLED_CREALITY was not renamed back."

# Guppy startup service must be absent unless it genuinely existed before install.
if [ -f "$SOURCE_BACKUP/had_service" ]; then
    echo "A pre-existing GuppyScreen service was present before installation; restoring it."
else
    [ ! -e "$INIT_DIR/$SERVICE" ] || fail "$SERVICE was not removed."
fi

echo "Original file state restored."

echo
echo "[7/8] Verifying complete restoration..."

verify_restored "$SOURCE_BACKUP" || fail "Final restoration verification failed."

# The stock GUI is restored but must not be started by this script.
# The printer's normal init system will handle it on the next normal boot.
# If the original service was already running before uninstall, we cannot
# safely infer that from the backup alone, so we deliberately do not launch it here.

echo "Original state verified."
echo "guppyconfig.json was NOT touched."

echo
echo "[8/8] Final safety validation..."

[ "$(count_guppy)" = "0" ] || fail "A GuppyScreen process is still running."

[ -f "$INIT_DIR/$CREALITY_SERVICE" ] || fail "Stock Creality GUI service is missing."
[ ! -e "$INIT_DIR/$DISABLED_CREALITY" ] || fail "Disabled Creality service was not renamed back."

if [ ! -f "$SOURCE_BACKUP/had_binary" ]; then
    [ ! -e "$INSTALL_DIR/guppyscreen" ] || fail "GuppyScreen binary still exists."
fi

if [ ! -f "$SOURCE_BACKUP/had_assets" ]; then
    [ ! -e "$INSTALL_DIR/assets" ] || fail "GuppyScreen assets still exist."
fi

if [ ! -f "$SOURCE_BACKUP/had_themes" ]; then
    [ ! -e "$INSTALL_DIR/themes" ] || fail "GuppyScreen themes still exist."
fi

ROLLBACK_NEEDED=0

echo
echo "============================================================"
echo "             UNINSTALL SUCCESSFUL"
echo "============================================================"
echo
echo "Stock GUI     : $INIT_DIR/$CREALITY_SERVICE"
echo "Guppy service : removed/restored to pre-install state"
echo "Guppy files   : removed/restored to pre-install state"
echo "Config        : guppyconfig.json was NOT touched"
echo "Source backup : $SOURCE_BACKUP"
echo "Emergency     : $EMERGENCY_BACKUP"
echo
echo "The printer has been restored to the state from before"
echo "the GuppyScreen installation."
echo
echo "No reboot was performed."
echo "============================================================"
echo

exit 0
