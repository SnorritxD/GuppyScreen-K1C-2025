# GuppyScreen-K1C-2025

A custom **GuppyScreen build for the Creality K1C 2025/2026**.

This project brings GuppyScreen support to the newer K1C hardware platform using the **X2600 / XBurst II MIPS32 little-endian architecture**.

This release is specifically intended for the **Creality K1C 2025/2026**.

---

## Features

* Creality K1C 2025/2026 support
* X2600 / XBurst II MIPS32 little-endian support
* Display framebuffer support using **`/dev/fb1`**
* 800 × 480 display resolution
* 32 bpp display format
* Touchscreen support using **`/dev/input/event1`**
* `goodix-ts` touchscreen support
* `jzfb` framebuffer driver support
* Custom GuppyScreen startup service
* Bundled assets and themes
* Automatic installation
* Safe, verified backups before changes
* Idempotent installation — safe to run again
* Automatic detection of an existing GuppyScreen installation
* Restore/uninstall functionality

---

# ⚠️ Warning / Disclaimer

**Use this software completely at your own risk.**

This software modifies system components on your Creality K1C.

Although the installer and uninstall process are designed with safety checks, backups, validation and rollback protection, unexpected problems can always occur.

Possible risks include:

* GUI not starting
* Printer requiring firmware recovery
* Settings loss
* Incompatibility with future Creality firmware updates
* Other unexpected printer malfunctions

The author of this repository is **not responsible for any damage, malfunction, data loss, or unusable printers** caused by using this software.

Always make sure you understand what the installer does before running it.

By installing this software, you acknowledge that you are doing so voluntarily and at your own risk.

---

# Supported Hardware

This release is intended for:

| Component           | Value                         |
| ------------------- | ----------------------------- |
| Printer             | Creality K1C 2025/2026        |
| SoC                 | X2600 / XBurst II             |
| Architecture        | MIPS32 little endian          |
| Display framebuffer | `/dev/fb1`                    |
| Display resolution  | 800 × 480                     |
| Display format      | 32 bpp                        |
| Touch input         | `/dev/input/event1`           |
| Touch driver        | `goodix-ts`                   |
| Framebuffer driver  | `jzfb`                        |
| Creality GUI        | `CS60gui_service` / `vectorp` |

> **Important:** This installer is specifically for the Creality K1C 2025/2026 hardware platform. Other Creality printer models are not supported by this release.

---

# What Does the Installation Do?

The installer installs GuppyScreen as a separate application.

The final runtime installation is located at:

```text
/usr/data/guppyscreen/
```

The Git repository is stored separately at:

```text
/usr/data/GuppyScreen-K1C-2025/
```

The resulting layout is:

```text
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

The repository is used for installation and updates.

The active GuppyScreen application runs from:

```text
/usr/data/guppyscreen/guppyscreen
```

---

# Changes Made to the Printer

## 1. Creality GUI

The original Creality GUI startup service is:

```text
/usr/apps/etc/init.d/CS60gui_service
```

During GuppyScreen installation, the installer disables the original service by **renaming** it to:

```text
/usr/apps/etc/init.d/disabled.CS60gui_service
```

The original service is not permanently deleted.

A verified safety backup is created before changes are made.

During normal uninstall, the stock Creality GUI is restored by renaming:

```text
disabled.CS60gui_service
```

back to:

```text
CS60gui_service
```

The installer and uninstaller are specifically designed not to delete the original Creality GUI service.

---

## 2. GuppyScreen Startup Service

A custom GuppyScreen startup service is installed at:

```text
/usr/apps/etc/init.d/S57guppy_service
```

This service:

* waits for Moonraker and Klipper to become ready
* starts GuppyScreen automatically
* starts GuppyScreen after reboot

---

## 3. GuppyScreen Application

The following files are installed under:

```text
/usr/data/guppyscreen/
```

Including:

```text
guppyscreen
assets/
themes/
```

Assets include:

* Material icons
* Fonts
* SVG resources
* Other GuppyScreen resources

Included themes include:

* Blue
* Green
* Pink
* Purple
* Red
* Yellow

---

# Configuration

GuppyScreen automatically creates:

```text
guppyconfig.json
```

when required.

**The installer does not overwrite or modify `guppyconfig.json`.**

This means existing GuppyScreen configuration is preserved when reinstalling or updating.

---

# Installation

## Requirements

Your printer must have:

* Creality K1C 2025/2026 hardware
* Root access
* SSH access
* Internet connection
* `wget`
* `git`

---

# Automatic Installation

Run the following command on the printer:

```sh
sh -c "$(wget -qO- https://raw.githubusercontent.com/SnorritxD/GuppyScreen-K1C-2025/main/install.sh)"
```

The installer will:

1. Download or update the repository
2. Run hardware and environment checks
3. Detect the existing installation state
4. Create and verify a safety backup before making changes
5. Stop an existing GuppyScreen process if necessary
6. Prepare the Creality GUI
7. Install or update GuppyScreen files
8. Install or update the startup service
9. Validate the installation
10. Start GuppyScreen
11. Perform final safety validation

If GuppyScreen is already installed, the installer will detect existing components and only update components that require changes.

---
