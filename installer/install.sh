#!/bin/sh
# GuppyScreen K1C 2025/2026 - public fail-safe installer
#
# Safety rules:
#   - Only root may run this installer.
#   - Only the known K1C 2025/2026 hardware layout is accepted.
#   - Ambiguous Creality GUI states are rejected before any change.
#   - Existing files are backed up and the backup is content-verified.
#   - User-generated guppyconfig.json is never copied, removed or replaced.
#   - Components are installed one at a time and verified afterwards.
#   - Any failure after modifications triggers automatic rollback.
#   - A fully correct installation is left completely untouched.

set -u
umask 022

INSTALL_DIR="/usr/data/guppyscreen"
INIT_DIR="/usr/apps/etc/init.d"
BACKUP_ROOT="/usr/data/guppyscreen-k1c-backup"
SERVICE="S57guppy_service"
CREALITY_SERVICE="CS60gui_service"
DISABLED_CREALITY="disabled.$CREALITY_SERVICE"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP=""
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

verify_file()
{
    cmp -s "$1" "$2" || fail "File verification failed: $1"
}

verify_dir()
{
    diff -qr "$1" "$2" >/dev/null 2>&1 || fail "Directory verification failed: $1"
}

rollback()
{
    # Do not let an error inside rollback prevent the remaining restore steps.
    set +e

    echo
    echo "============================================================"
    echo "                AUTOMATIC ROLLBACK"
    echo "============================================================"
    echo

    [ -n "$BACKUP" ] || exit 1
    [ -d "$BACKUP" ] || exit 1

    # Stop the newly installed GuppyScreen first.
    if [ -x "$INIT_DIR/$SERVICE" ]; then
        "$INIT_DIR/$SERVICE" stop >/dev/null 2>&1 || true
    fi
    sleep 1

    # Restore service exactly as it existed before installation.
    rm -f "$INIT_DIR/$SERVICE"
    if [ -f "$BACKUP/had_service" ]; then
        cp -p "$BACKUP/$SERVICE" "$INIT_DIR/$SERVICE" || true
        chmod 755 "$INIT_DIR/$SERVICE" 2>/dev/null || true
    fi

    # Restore the exact Creality GUI state.
    rm -f "$INIT_DIR/$CREALITY_SERVICE" "$INIT_DIR/$DISABLED_CREALITY"
    if [ -f "$BACKUP/had_creality_active" ]; then
        cp -p "$BACKUP/$CREALITY_SERVICE" "$INIT_DIR/$CREALITY_SERVICE" || true
    fi
    if [ -f "$BACKUP/had_creality_disabled" ]; then
        cp -p "$BACKUP/$DISABLED_CREALITY" "$INIT_DIR/$DISABLED_CREALITY" || true
    fi

    # Restore binary exactly, or remove it if it did not exist before.
    if [ -f "$BACKUP/had_binary" ]; then
        mkdir -p "$INSTALL_DIR"
        cp -p "$BACKUP/guppyscreen" "$INSTALL_DIR/guppyscreen" || true
        chmod 755 "$INSTALL_DIR/guppyscreen" 2>/dev/null || true
    else
        rm -f "$INSTALL_DIR/guppyscreen"
    fi

    # Restore assets exactly, or remove newly-created assets.
    if [ -f "$BACKUP/had_assets" ]; then
        rm -rf "$INSTALL_DIR/assets"
        cp -a "$BACKUP/assets" "$INSTALL_DIR/assets" || true
    else
        rm -rf "$INSTALL_DIR/assets"
    fi

    # Restore themes exactly, or remove newly-created themes.
    if [ -f "$BACKUP/had_themes" ]; then
        rm -rf "$INSTALL_DIR/themes"
        cp -a "$BACKUP/themes" "$INSTALL_DIR/themes" || true
    else
        rm -rf "$INSTALL_DIR/themes"
    fi

    # Verify restored files where possible. A failed verification is reported.
    RESTORE_OK=1
    if [ -f "$BACKUP/had_binary" ]; then
        cmp -s "$BACKUP/guppyscreen" "$INSTALL_DIR/guppyscreen" || RESTORE_OK=0
    else
        [ ! -e "$INSTALL_DIR/guppyscreen" ] || RESTORE_OK=0
    fi
    if [ -f "$BACKUP/had_assets" ]; then
        diff -qr "$BACKUP/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1 || RESTORE_OK=0
    else
        [ ! -e "$INSTALL_DIR/assets" ] || RESTORE_OK=0
    fi
    if [ -f "$BACKUP/had_themes" ]; then
        diff -qr "$BACKUP/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1 || RESTORE_OK=0
    else
        [ ! -e "$INSTALL_DIR/themes" ] || RESTORE_OK=0
    fi

    # Restart the previous GuppyScreen only if it was running before.
    if [ "$ORIGINAL_PROCESS_COUNT" = "1" ] && [ -x "$INIT_DIR/$SERVICE" ]; then
        "$INIT_DIR/$SERVICE" start >/dev/null 2>&1 || true
        WAIT=20
        while [ "$WAIT" -gt 0 ]; do
            [ "$(count_guppy)" = "1" ] && break
            sleep 1
            WAIT=$((WAIT - 1))
        done
        [ "$(count_guppy)" = "1" ] || RESTORE_OK=0
    fi

    if [ "$RESTORE_OK" = "1" ]; then
        echo "[ROLLBACK] Previous state restored and verified."
        echo "[ROLLBACK] guppyconfig.json was never touched."
    else
        echo "[ROLLBACK] WARNING: restore verification FAILED." >&2
        echo "[ROLLBACK] Do NOT reboot or retry blindly. Backup: $BACKUP" >&2
    fi

    exit 1
}

trap 'if [ "$ROLLBACK_NEEDED" = "1" ]; then rollback; fi' EXIT INT TERM

echo
echo "============================================================"
echo "      GuppyScreen K1C 2025/2026 Installer"
echo "             FAIL-SAFE + IDEMPOTENT"
echo "============================================================"
echo

echo "[1/9] Preflight checks..."

[ "$(id -u)" = "0" ] || fail "Run this installer as root."
[ -x "$SCRIPT_DIR/guppyscreen" ] || fail "Missing executable: guppyscreen"
[ -d "$SCRIPT_DIR/assets" ] || fail "Missing directory: assets"
[ -d "$SCRIPT_DIR/themes" ] || fail "Missing directory: themes"
[ -f "$SCRIPT_DIR/init/$SERVICE" ] || fail "Missing service: $SERVICE"
[ -d "/usr/data" ] || fail "/usr/data does not exist."
[ -d "$INIT_DIR" ] || fail "$INIT_DIR does not exist."

for cmd in uname cmp diff pgrep wc cp mv rm mkdir chmod date sleep wget start-stop-daemon; do
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
echo "[2/9] Checking existing installation state..."

if [ -f "$INIT_DIR/$CREALITY_SERVICE" ] && [ -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
    fail "Both $CREALITY_SERVICE and $DISABLED_CREALITY exist. State is ambiguous. No changes made."
fi

# A public installer must never guess what happened to the stock GUI.
if [ ! -f "$INIT_DIR/$CREALITY_SERVICE" ] && [ ! -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
    fail "Neither $CREALITY_SERVICE nor $DISABLED_CREALITY exists. Refusing to guess the printer state."
fi

binary_ok=0
service_ok=0
assets_ok=0
themes_ok=0
creality_ok=0
process_ok=0

if [ -f "$INSTALL_DIR/guppyscreen" ] &&
   [ -x "$INSTALL_DIR/guppyscreen" ] &&
   cmp -s "$SCRIPT_DIR/guppyscreen" "$INSTALL_DIR/guppyscreen"; then
    binary_ok=1
fi

if [ -f "$INIT_DIR/$SERVICE" ] &&
   [ -x "$INIT_DIR/$SERVICE" ] &&
   cmp -s "$SCRIPT_DIR/init/$SERVICE" "$INIT_DIR/$SERVICE"; then
    service_ok=1
fi

if [ -d "$INSTALL_DIR/assets" ] &&
   diff -qr "$SCRIPT_DIR/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1; then
    assets_ok=1
fi

if [ -d "$INSTALL_DIR/themes" ] &&
   diff -qr "$SCRIPT_DIR/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1; then
    themes_ok=1
fi

if [ ! -f "$INIT_DIR/$CREALITY_SERVICE" ] &&
   [ -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
    creality_ok=1
fi

COUNT="$(count_guppy)"
[ "$COUNT" = "1" ] && process_ok=1
ORIGINAL_PROCESS_COUNT="$COUNT"

echo "Binary          : $([ "$binary_ok" = "1" ] && echo OK || echo NEEDS_INSTALL)"
echo "Assets          : $([ "$assets_ok" = "1" ] && echo OK || echo NEEDS_INSTALL)"
echo "Themes          : $([ "$themes_ok" = "1" ] && echo OK || echo NEEDS_INSTALL)"
echo "Startup service : $([ "$service_ok" = "1" ] && echo OK || echo NEEDS_INSTALL)"
echo "Creality GUI    : $([ "$creality_ok" = "1" ] && echo DISABLED || echo NEEDS_ACTION)"
echo "GuppyScreen     : $([ "$process_ok" = "1" ] && echo RUNNING || echo NOT_RUNNING)"

if [ "$binary_ok" = "1" ] &&
   [ "$assets_ok" = "1" ] &&
   [ "$themes_ok" = "1" ] &&
   [ "$service_ok" = "1" ] &&
   [ "$creality_ok" = "1" ] &&
   [ "$process_ok" = "1" ]; then
    echo
echo "============================================================"
    echo "                 ALREADY INSTALLED"
    echo "============================================================"
    echo
    echo "Everything is already correct."
    echo "NO CHANGES WERE MADE."
    echo "No backup was created because nothing changed."
    echo "guppyconfig.json was not touched."
    echo
    exit 0
fi

echo
echo "Installation is incomplete or differs from this package."
echo "A verified safety backup will be created before any change."

echo
echo "[3/9] Creating and verifying safety backup..."

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"

# Prevent an accidental collision with an existing backup timestamp.
[ ! -e "$BACKUP" ] || fail "Backup directory already exists: $BACKUP"

mkdir -p "$BACKUP" || fail "Cannot create backup directory: $BACKUP"
echo "GuppyScreen K1C installer backup" > "$BACKUP/README" || fail "Cannot create backup marker."

if [ -f "$INSTALL_DIR/guppyscreen" ]; then
    touch "$BACKUP/had_binary"
    cp -p "$INSTALL_DIR/guppyscreen" "$BACKUP/guppyscreen" || fail "Cannot backup existing guppyscreen."
fi

if [ -d "$INSTALL_DIR/assets" ]; then
    touch "$BACKUP/had_assets"
    cp -a "$INSTALL_DIR/assets" "$BACKUP/assets" || fail "Cannot backup existing assets."
fi

if [ -d "$INSTALL_DIR/themes" ]; then
    touch "$BACKUP/had_themes"
    cp -a "$INSTALL_DIR/themes" "$BACKUP/themes" || fail "Cannot backup existing themes."
fi

if [ -f "$INIT_DIR/$SERVICE" ]; then
    touch "$BACKUP/had_service"
    cp -p "$INIT_DIR/$SERVICE" "$BACKUP/$SERVICE" || fail "Cannot backup existing $SERVICE."
fi

if [ -f "$INIT_DIR/$CREALITY_SERVICE" ]; then
    touch "$BACKUP/had_creality_active"
    cp -p "$INIT_DIR/$CREALITY_SERVICE" "$BACKUP/$CREALITY_SERVICE" || fail "Cannot backup $CREALITY_SERVICE."
fi

if [ -f "$INIT_DIR/$DISABLED_CREALITY" ]; then
    touch "$BACKUP/had_creality_disabled"
    cp -p "$INIT_DIR/$DISABLED_CREALITY" "$BACKUP/$DISABLED_CREALITY" || fail "Cannot backup $DISABLED_CREALITY."
fi

[ -f "$BACKUP/README" ] || fail "Backup marker verification failed."

if [ -f "$BACKUP/had_binary" ]; then
    [ -f "$BACKUP/guppyscreen" ] || fail "Binary backup verification failed."
    cmp -s "$INSTALL_DIR/guppyscreen" "$BACKUP/guppyscreen" || fail "Binary backup content verification failed."
fi

if [ -f "$BACKUP/had_assets" ]; then
    [ -d "$BACKUP/assets" ] || fail "Assets backup verification failed."
    diff -qr "$INSTALL_DIR/assets" "$BACKUP/assets" >/dev/null 2>&1 || fail "Assets backup content verification failed."
fi

if [ -f "$BACKUP/had_themes" ]; then
    [ -d "$BACKUP/themes" ] || fail "Themes backup verification failed."
    diff -qr "$INSTALL_DIR/themes" "$BACKUP/themes" >/dev/null 2>&1 || fail "Themes backup content verification failed."
fi

if [ -f "$BACKUP/had_service" ]; then
    [ -f "$BACKUP/$SERVICE" ] || fail "Service backup verification failed."
    cmp -s "$INIT_DIR/$SERVICE" "$BACKUP/$SERVICE" || fail "Service backup content verification failed."
fi

if [ -f "$BACKUP/had_creality_active" ]; then
    [ -f "$BACKUP/$CREALITY_SERVICE" ] || fail "Creality service backup verification failed."
    cmp -s "$INIT_DIR/$CREALITY_SERVICE" "$BACKUP/$CREALITY_SERVICE" || fail "Creality service backup content verification failed."
fi

if [ -f "$BACKUP/had_creality_disabled" ]; then
    [ -f "$BACKUP/$DISABLED_CREALITY" ] || fail "Disabled Creality backup verification failed."
    cmp -s "$INIT_DIR/$DISABLED_CREALITY" "$BACKUP/$DISABLED_CREALITY" || fail "Disabled Creality backup content verification failed."
fi

echo "Backup verified: $BACKUP"
ROLLBACK_NEEDED=1

echo
echo "[4/9] Stopping existing GuppyScreen..."
stop_guppy

# Refuse to continue if an unexpected GuppyScreen process remains.
[ "$(count_guppy)" = "0" ] || fail "GuppyScreen process did not stop safely."

echo
echo "[5/9] Preparing Creality GUI..."

if [ -f "$INIT_DIR/$CREALITY_SERVICE" ]; then
    # Destination must not exist; ambiguity was checked above.
    [ ! -e "$INIT_DIR/$DISABLED_CREALITY" ] || fail "Disabled Creality service unexpectedly appeared."
    mv "$INIT_DIR/$CREALITY_SERVICE" "$INIT_DIR/$DISABLED_CREALITY" || fail "Cannot disable $CREALITY_SERVICE."
fi

[ ! -f "$INIT_DIR/$CREALITY_SERVICE" ] || fail "$CREALITY_SERVICE is still active."
[ -f "$INIT_DIR/$DISABLED_CREALITY" ] || fail "Creality GUI disabled state is missing."

echo
echo "[6/9] Installing required components..."
mkdir -p "$INSTALL_DIR" || fail "Cannot create $INSTALL_DIR."

# Binary: copy to a temporary file, verify it, then replace the live file.
if [ "$binary_ok" = "1" ]; then
    echo "Binary: already correct."
else
    echo "Binary: installing..."
    TMP_BINARY="$INSTALL_DIR/.guppyscreen.install.tmp"
    rm -f "$TMP_BINARY"
    cp -p "$SCRIPT_DIR/guppyscreen" "$TMP_BINARY" || fail "Cannot stage guppyscreen."
    chmod 755 "$TMP_BINARY" || fail "Cannot chmod staged guppyscreen."
    cmp -s "$SCRIPT_DIR/guppyscreen" "$TMP_BINARY" || fail "Staged binary verification failed."
    mv "$TMP_BINARY" "$INSTALL_DIR/guppyscreen" || fail "Cannot activate guppyscreen."
    cmp -s "$SCRIPT_DIR/guppyscreen" "$INSTALL_DIR/guppyscreen" || fail "Installed binary verification failed."
fi

# Assets: stage the complete directory first; never delete the old copy until staging succeeded.
if [ "$assets_ok" = "1" ]; then
    echo "Assets: already correct."
else
    echo "Assets: installing..."
    TMP_ASSETS="$INSTALL_DIR/.assets.install.tmp"
    OLD_ASSETS="$INSTALL_DIR/.assets.previous.tmp"
    rm -rf "$TMP_ASSETS" "$OLD_ASSETS"
    cp -a "$SCRIPT_DIR/assets" "$TMP_ASSETS" || fail "Cannot stage assets."
    diff -qr "$SCRIPT_DIR/assets" "$TMP_ASSETS" >/dev/null 2>&1 || fail "Staged assets verification failed."
    if [ -e "$INSTALL_DIR/assets" ]; then
        mv "$INSTALL_DIR/assets" "$OLD_ASSETS" || fail "Cannot move old assets safely."
    fi
    if ! mv "$TMP_ASSETS" "$INSTALL_DIR/assets"; then
        rm -rf "$INSTALL_DIR/assets"
        if [ -e "$OLD_ASSETS" ]; then mv "$OLD_ASSETS" "$INSTALL_DIR/assets"; fi
        fail "Cannot activate assets."
    fi
    rm -rf "$OLD_ASSETS"
    diff -qr "$SCRIPT_DIR/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1 || fail "Installed assets verification failed."
fi

# Themes: same staged replacement procedure.
if [ "$themes_ok" = "1" ]; then
    echo "Themes: already correct."
else
    echo "Themes: installing..."
    TMP_THEMES="$INSTALL_DIR/.themes.install.tmp"
    OLD_THEMES="$INSTALL_DIR/.themes.previous.tmp"
    rm -rf "$TMP_THEMES" "$OLD_THEMES"
    cp -a "$SCRIPT_DIR/themes" "$TMP_THEMES" || fail "Cannot stage themes."
    diff -qr "$SCRIPT_DIR/themes" "$TMP_THEMES" >/dev/null 2>&1 || fail "Staged themes verification failed."
    if [ -e "$INSTALL_DIR/themes" ]; then
        mv "$INSTALL_DIR/themes" "$OLD_THEMES" || fail "Cannot move old themes safely."
    fi
    if ! mv "$TMP_THEMES" "$INSTALL_DIR/themes"; then
        rm -rf "$INSTALL_DIR/themes"
        if [ -e "$OLD_THEMES" ]; then mv "$OLD_THEMES" "$INSTALL_DIR/themes"; fi
        fail "Cannot activate themes."
    fi
    rm -rf "$OLD_THEMES"
    diff -qr "$SCRIPT_DIR/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1 || fail "Installed themes verification failed."
fi

# Service: stage, verify, then activate.
if [ "$service_ok" = "1" ]; then
    echo "Startup service: already correct."
else
    echo "Startup service: installing..."
    TMP_SERVICE="$INIT_DIR/.$SERVICE.install.tmp"
    rm -f "$TMP_SERVICE"
    cp -p "$SCRIPT_DIR/init/$SERVICE" "$TMP_SERVICE" || fail "Cannot stage $SERVICE."
    chmod 755 "$TMP_SERVICE" || fail "Cannot chmod staged $SERVICE."
    cmp -s "$SCRIPT_DIR/init/$SERVICE" "$TMP_SERVICE" || fail "Staged service verification failed."
    mv "$TMP_SERVICE" "$INIT_DIR/$SERVICE" || fail "Cannot activate $SERVICE."
    cmp -s "$SCRIPT_DIR/init/$SERVICE" "$INIT_DIR/$SERVICE" || fail "Installed service verification failed."
fi

# Explicitly document the config invariant.
echo
echo "guppyconfig.json: UNTOUCHED."

echo
echo "[7/9] Validating complete installation..."

[ -x "$INSTALL_DIR/guppyscreen" ] || fail "Installed binary is not executable."
cmp -s "$SCRIPT_DIR/guppyscreen" "$INSTALL_DIR/guppyscreen" || fail "Installed binary differs from package."
[ -d "$INSTALL_DIR/assets" ] || fail "Installed assets directory missing."
diff -qr "$SCRIPT_DIR/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1 || fail "Installed assets differ from package."
[ -d "$INSTALL_DIR/themes" ] || fail "Installed themes directory missing."
diff -qr "$SCRIPT_DIR/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1 || fail "Installed themes differ from package."
[ -x "$INIT_DIR/$SERVICE" ] || fail "Installed service is not executable."
cmp -s "$SCRIPT_DIR/init/$SERVICE" "$INIT_DIR/$SERVICE" || fail "Installed service differs from package."
[ ! -f "$INIT_DIR/$CREALITY_SERVICE" ] || fail "$CREALITY_SERVICE is still active."
[ -f "$INIT_DIR/$DISABLED_CREALITY" ] || fail "Creality GUI disabled state is missing."

# Installer must not have created/modified the user config.
# We intentionally do not require the file to exist: GuppyScreen creates it on first start.
echo "Installation files validated successfully."

echo
echo "[8/9] Starting GuppyScreen..."

"$INIT_DIR/$SERVICE" start || fail "Could not start GuppyScreen service."

WAIT=70
while [ "$WAIT" -gt 0 ]; do
    COUNT="$(count_guppy)"
    if [ "$COUNT" = "1" ]; then
        break
    fi
    if [ "$COUNT" -gt 1 ]; then
        fail "More than one GuppyScreen process appeared ($COUNT)."
    fi
    sleep 1
    WAIT=$((WAIT - 1))
done

[ "$(count_guppy)" = "1" ] || fail "GuppyScreen did not start within 70 seconds."

echo
echo "[9/9] Final safety validation..."

# Final exact process count.
COUNT="$(count_guppy)"
[ "$COUNT" = "1" ] || fail "Expected exactly one GuppyScreen process, found $COUNT."

# No temporary installation artifacts may remain.
[ ! -e "$INSTALL_DIR/.guppyscreen.install.tmp" ] || fail "Temporary binary artifact remains."
[ ! -e "$INSTALL_DIR/.assets.install.tmp" ] || fail "Temporary assets artifact remains."
[ ! -e "$INSTALL_DIR/.themes.install.tmp" ] || fail "Temporary themes artifact remains."
[ ! -e "$INIT_DIR/.$SERVICE.install.tmp" ] || fail "Temporary service artifact remains."

# Verify the package files one final time.
cmp -s "$SCRIPT_DIR/guppyscreen" "$INSTALL_DIR/guppyscreen" || fail "Final binary verification failed."
diff -qr "$SCRIPT_DIR/assets" "$INSTALL_DIR/assets" >/dev/null 2>&1 || fail "Final assets verification failed."
diff -qr "$SCRIPT_DIR/themes" "$INSTALL_DIR/themes" >/dev/null 2>&1 || fail "Final themes verification failed."
cmp -s "$SCRIPT_DIR/init/$SERVICE" "$INIT_DIR/$SERVICE" || fail "Final service verification failed."

ROLLBACK_NEEDED=0

echo
echo "============================================================"
echo "              INSTALLATION SUCCESSFUL"
echo "============================================================"
echo
echo "GuppyScreen : $INSTALL_DIR/guppyscreen"
echo "Service     : $INIT_DIR/$SERVICE"
echo "Creality GUI: $INIT_DIR/$DISABLED_CREALITY"
echo "Backup      : $BACKUP"
echo
echo "Process count: 1"
echo
echo "guppyconfig.json was NOT touched."
echo "Previous state is preserved in the backup."
echo
echo "GuppyScreen is now running."
echo "============================================================"
echo

exit 0
