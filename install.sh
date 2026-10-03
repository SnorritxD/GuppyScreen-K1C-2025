#!/bin/sh

set -e

REPO="https://github.com/SnorritxD/GuppyScreen-K1C-2025.git"
DIR="/usr/data/GuppyScreen-K1C-2025"

echo "=================================="
echo "GuppyScreen K1C 2025 Installer"
echo "=================================="

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is required"
    exit 1
fi

if [ -d "$DIR/.git" ]; then
    echo "Updating repository..."
    cd "$DIR"
    git pull
else
    echo "Cloning repository..."
    cd /usr/data

    if [ -e "$DIR" ]; then
        echo "ERROR: $DIR already exists but is not a git repository."
        echo "Remove it manually or move it before installing."
        exit 1
    fi

    git clone "$REPO" "$DIR"
fi

cd "$DIR"

chmod +x installer/install.sh
chmod +x uninstall.sh

./installer/install.sh
