# GuppyScreen-K1C-2025

A custom **GuppyScreen build for the Creality K1C 2025/2026**.

This project is focused on bringing GuppyScreen support to the newer K1C hardware platform using the X2600 MIPS32 little endian architecture.

This release includes:

- K1C 2025/2026 hardware support
- framebuffer support using `fb1`
- touchscreen support using `event1`
- custom startup service
- bundled assets and themes
- safe installation and uninstall procedure

---

# ⚠️ Warning / Disclaimer

**Use this software completely at your own risk.**

This software modifies system components on your Creality K1C.

Although the installer and uninstall process are designed to be safe, unexpected problems can always occur.

Possible risks include:

- GUI not starting
- printer requiring firmware recovery
- settings loss
- incompatibility with future Creality firmware updates

The author of this repository is **not responsible for any damage, malfunction, data loss, or unusable printers** caused by using this software.

Always make a backup before installing.

By installing this software, you acknowledge that you are doing this voluntarily and at your own risk.

---

# Supported Hardware

This build is intended for:

| Component | Value |
|---|---|
| Printer | Creality K1C 2025/2026 |
| SoC | X2600 |
| Architecture | MIPS32 little endian |
| Display framebuffer | `fb1` |
| Touch input | `event1` |
| Display system | Creality vectorp / CS60gui_service environment |

---

# What does this installation do?

This installer installs GuppyScreen as a separate application.

The final layout on the printer will be:

```
/usr/data/
│
├── GuppyScreen-K1C-2025/
│   └── Git repository
│
└── guppyscreen/
    ├── guppyscreen
    ├── assets/
    └── themes/
```

The Git repository is used for updates.

The active GuppyScreen installation runs from:

```
/usr/data/guppyscreen/
```

---

# Changes made to the printer

## 1. Disable the original Creality GUI startup

The original Creality GUI service:

```
CS60gui_service
```

is disabled during installation.

The installer does **not permanently delete it**.

A backup is created so it can be restored by the uninstall script.

---

## 2. Install GuppyScreen startup service

A new startup service is installed:

```
/usr/apps/etc/init.d/S57guppy_service
```

This service:

- waits for Moonraker and Klipper to become ready
- starts GuppyScreen automatically
- starts GuppyScreen after every reboot

---

## 3. Install application files

The following files are installed:

```
/usr/data/guppyscreen/
```

Including:

```
guppyscreen
assets/
themes/
```

Assets contain:

- Material icons
- fonts
- SVG resources

Themes include:

- blue
- green
- pink
- purple
- red
- yellow

---

# Installation

## Requirements

Your printer must have:

- root access
- SSH access
- internet connection
- git installed

---

# Automatic installation

Run this command on your printer:

```sh
sh -c "$(wget -qO- https://raw.githubusercontent.com/SnorritxD/GuppyScreen-K1C-2025/main/install.sh)"
```

The installer will:

1. Download the repository
2. Update the repository if it already exists
3. Verify required files
4. Install GuppyScreen
5. Install the startup service
6. Start GuppyScreen

---

# Manual installation

Alternatively:

```sh
cd /usr/data

git clone https://github.com/SnorritxD/GuppyScreen-K1C-2025.git

cd GuppyScreen-K1C-2025

chmod +x install.sh

./install.sh
```

---

# What happens during installation?

The installer will:

## Create backups

Backups are created for:

- existing GuppyScreen files
- Creality GUI startup service
- assets
- themes

---

## Stop existing GuppyScreen

If an existing GuppyScreen process is running, it will be stopped before installation.

---

## Install new files

The installer installs and verifies:

- GuppyScreen binary
- assets
- themes
- startup service

---

## Start GuppyScreen

After a successful installation:

```
S57guppy_service start
```

is executed.

---

# Uninstall / Restore original Creality GUI

To return to the original printer state:

```sh
cd /usr/data/GuppyScreen-K1C-2025

chmod +x uninstall.sh

./uninstall.sh
```

The uninstall script will:

- stop GuppyScreen
- remove the GuppyScreen startup service
- remove installed GuppyScreen files
- restore the original Creality GUI service
- restore backups when available

After uninstall:

```sh
reboot
```

---

# Updating

To update to the latest version:

```sh
cd /usr/data/GuppyScreen-K1C-2025

git pull

./install.sh
```

The installer will update the installed files.

---

# Troubleshooting

## Check if GuppyScreen is running

```sh
ps | grep guppyscreen
```

## Restart the service

```sh
/usr/apps/etc/init.d/S57guppy_service restart
```

## Check logs

```sh
logread | grep guppy
```

---

# Project Status

This project is specifically developed for:

**Creality K1C 2025/2026**

Other printer models are currently not tested.

---

# Credits

Based on the original GuppyScreen project.

This repository contains adaptations and packaging focused on supporting the newer Creality K1C 2025/2026 hardware platform.

---

# License

Please refer to the original GuppyScreen license and this repository's license information.
