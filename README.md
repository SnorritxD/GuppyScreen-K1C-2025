<div align="center">

# 🖥️ GuppyScreen-K1C-2025

<strong>A custom GuppyScreen build for the Creality K1C 2025/2026</strong>

<br>

This project brings GuppyScreen support to the newer K1C hardware platform using the X2600 / XBurst II MIPS32 little-endian architecture.

<br>

<img src="https://img.shields.io/badge/Printer-Creality%20K1C%202025%2F2026-blue?style=for-the-badge">
<img src="https://img.shields.io/badge/Architecture-X2600%20MIPS-orange?style=for-the-badge">
<img src="https://img.shields.io/badge/Display-/dev/fb1-green?style=for-the-badge">
<img src="https://img.shields.io/badge/Touch-goodix--ts-purple?style=for-the-badge">

</div>

---

## 📖 Overview

This project provides a custom GuppyScreen build specifically for the **Creality K1C 2025/2026** hardware platform.

The project brings GuppyScreen support to the newer Creality hardware using the:

- Ingenic X2600 / XBurst II MIPS32 little-endian architecture
- jzfb framebuffer driver
- goodix-ts touchscreen driver

This release is designed specifically for the K1C 2025/2026 and is not intended for older K1C versions or other Creality printers.

> [!IMPORTANT]
> This software modifies system components on your printer. Always understand what the installer changes before running it.

---

# ✨ Features

| Feature | Description |
|---|---|
| 🖥️ **Creality K1C 2025/2026 support** | Designed specifically for the newer K1C hardware platform. |
| ⚙️ **X2600 / XBurst II support** | Built for the MIPS32 little-endian architecture used by the K1C 2025/2026. |
| 🖼️ **Framebuffer support** | Uses `/dev/fb1` with 800 × 480 resolution. |
| 👆 **Touchscreen support** | Uses `/dev/input/event1` with the goodix-ts driver. |
| 🚀 **Automatic startup** | Starts GuppyScreen automatically after reboot. |
| 🎨 **Bundled assets and themes** | Includes required icons, fonts, SVG resources and themes. |
| 🔒 **Safety backups** | Creates verified backups before modifying system components. |
| 🔄 **Restore support** | Restores the original Creality GUI during uninstall. |
| ♻️ **Safe reinstall** | Detects existing installations and avoids unnecessary changes. |

---

# ⚠️ Warning / Disclaimer

Use this software completely at your own risk.

This software modifies system components on your Creality K1C.

Although the installer and uninstall process include:

- Safety checks
- Backup creation
- Validation
- Restore functionality

unexpected problems can always occur.

Possible issues include:

- GUI not starting
- Firmware recovery being required
- Settings loss
- Compatibility issues after future Creality firmware updates
- Other unexpected printer behaviour

The author of this repository is not responsible for damage, malfunction, data loss, or unusable printers caused by using this software.

By installing this software, you acknowledge that you are doing so voluntarily and at your own risk.

---

# 🖨️ Supported Hardware

| Component | Value |
|---|---|
| Printer | Creality K1C 2025/2026 |
| SoC | Ingenic X2600 / XBurst II |
| Architecture | MIPS32 little endian |
| Display framebuffer | `/dev/fb1` |
| Display resolution | 800 × 480 |
| Display format | 32 bpp |
| Touch input | `/dev/input/event1` |
| Touch driver | goodix-ts |
| Framebuffer driver | jzfb |
| Original Creality GUI | CS60gui_service / vectorp |

> [!NOTE]
> This installer is specifically designed for the Creality K1C 2025/2026 hardware platform.

---

# 📂 Installation Layout

After installation the files are separated between the Git repository and the active application.

```
/usr/data/

├── GuppyScreen-K1C-2025/
│   └── Git repository
│
└── guppyscreen/
    ├── guppyscreen
    ├── assets/
    └── themes/
```

The active GuppyScreen application runs from:

```
/usr/data/guppyscreen/guppyscreen
```

The repository is stored separately for updates and maintenance.

---

# ⚙️ Changes Made To The Printer

## 1. Creality GUI

The original Creality GUI startup service is:

```
/usr/apps/etc/init.d/CS60gui_service
```

During installation it is disabled by renaming:

```
CS60gui_service
```

to:

```
disabled.CS60gui_service
```

The original service is not permanently deleted.

A safety backup is created before changes are made.

During uninstall the original service is restored:

```
disabled.CS60gui_service
```

back to:

```
CS60gui_service
```

---

## 2. GuppyScreen Startup Service

A custom startup service is installed:

```
/usr/apps/etc/init.d/S57guppy_service
```

This service:

- Waits for Moonraker and Klipper readiness
- Starts GuppyScreen automatically
- Starts GuppyScreen after reboot

---

## 3. GuppyScreen Application

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

Included resources:

- Material icons
- Fonts
- SVG resources
- GuppyScreen assets

Included themes:

- Blue
- Green
- Pink
- Purple
- Red
- Yellow

---

# 🛠️ Configuration

GuppyScreen automatically creates:

```
guppyconfig.json
```

when required.

The installer does not overwrite or modify an existing:

```
guppyconfig.json
```

Existing GuppyScreen settings are preserved during reinstall or updates.

---

# 🚀 Installation

## Requirements

Your printer must have:

- Creality K1C 2025/2026 hardware
- Root access
- SSH access
- Internet connection
- wget
- git

---

## Automatic Installation

Run the following command on the printer:

```sh
sh -c "$(wget -qO- https://raw.githubusercontent.com/SnorritxD/GuppyScreen-K1C-2025/main/install.sh)"
```

The installer will:

1. Download or update the repository.
2. Run hardware and environment checks.
3. Detect existing GuppyScreen installations.
4. Create and verify backups.
5. Stop an existing GuppyScreen process if required.
6. Prepare the Creality GUI.
7. Install or update GuppyScreen files.
8. Install the startup service.
9. Validate the installation.
10. Start GuppyScreen.

If GuppyScreen is already installed, the installer detects existing components and updates only required parts.

---

# 🔄 Restore / Uninstall

The uninstall process restores the original Creality GUI service.

The installer is designed to restore:

```
disabled.CS60gui_service
```

back to:

```
CS60gui_service
```

Original files are preserved whenever possible.

---

# 🧩 Troubleshooting

## GuppyScreen does not start

Check:

```
/usr/data/guppyscreen/
```

and verify that the executable exists.

Check the startup service:

```
/usr/apps/etc/init.d/S57guppy_service
```

---

## Touchscreen does not work

Verify:

```
/dev/input/event1
```

is available and matches the touchscreen device.

---

## Display problems

Verify:

```
/dev/fb1
```

is available and matches the expected framebuffer.

The supported configuration is:

```
800x480
32 bpp
jzfb framebuffer driver
```

---

# 🤝 Contributing

Community testing, compatibility reports and improvements are welcome.

When reporting issues, include:

- Printer model
- Firmware version
- Hardware information
- Error messages
- Relevant logs

---

# ⚠️ Final Disclaimer

This project is provided **as-is**.

Installing third-party software on a rooted 3D printer always carries risks. Always keep backups and make sure you understand the changes before installing.

---

<p align="center">
  <strong>Made for the Creality K1C community</strong> 🧡
</p>
