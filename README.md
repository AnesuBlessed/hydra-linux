<div align="center">

```
██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
███████║ ╚████╔╝ ██║  ██║██████╔╝███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
```

# Hydra Linux

**A complete, unified Hyprland desktop environment with Quickshell, Matugen dynamic theming, and Silent SDDM.**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20CachyOS-1793d1.svg?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Compositor: Hyprland](https://img.shields.io/badge/Compositor-Hyprland%20(Lua)-00c853.svg)](https://hyprland.org/)
[![Shell: Quickshell](https://img.shields.io/badge/Shell-Quickshell%20(Qt6)-673ab7.svg)](https://github.com/outfoxxed/quickshell)
[![Display Manager: Silent SDDM](https://img.shields.io/badge/Greeter-Silent%20SDDM%20(Animated)-e91e63.svg)](sddm/)

</div>

---

## Overview

Hydra Linux is a fully integrated desktop environment for Arch Linux and Arch-based distributions. It combines Hyprland (with native Lua configuration), the Quickshell desktop shell, Matugen wallpaper-driven color generation, and the Silent SDDM login greeter with animated video backgrounds.

Unlike minimal dotfile collections, Hydra Linux ships as a complete, unified system. The automated installer handles everything: dependency resolution, GPU detection, configuration deployment, font installation, display manager setup, and safe backups of your existing configs.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Default Keybindings](#default-keybindings)
- [Quickshell Widgets](#quickshell-widgets)
- [Silent SDDM Greeter](#silent-sddm-greeter)
- [Customization](#customization)
- [Repository Structure](#repository-structure)
- [Dependencies](#dependencies)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

### Hyprland with Dual-Engine Configuration

- Native Lua configuration (`hyprland.lua`, `config/*.lua`) providing type safety, modular design, and programmatic customization.
- Traditional `.conf` files maintained in parallel for compatibility.
- Dynamic GPU detection (NVIDIA, AMD, Intel) with automatic driver configuration.
- Comprehensive keybinding system with workspace management, window rules, and multi-monitor support.

### Quickshell Desktop Shell

A full-featured Qt6/QML desktop shell with 17 interactive widgets:

- Top bar with system tray, clock, workspace indicators, and status icons.
- Application launcher with fuzzy search.
- Dynamic wallpaper picker with thumbnail previews and DuckDuckGo image search.
- Calendar with integrated weather forecasts (Open-Meteo API, no API key required).
- Network manager (WiFi, Ethernet, Bluetooth panels with sound effects).
- Music player with album art and equalizer visualization.
- Volume and brightness controls with OSD overlays.
- Battery monitor with power profile switching.
- Focus time tracker with session statistics.
- Clipboard manager with history.
- Notification system.
- System settings panel (general, weather, keybinds, startup apps, profile avatar).
- Stewart AI assistant widget.
- Monitor management and display configuration.
- Interactive guide/tutorial system.

### Matugen Dynamic Theming

- Set any wallpaper and Matugen automatically generates a system-wide color palette.
- Colors propagate in real-time to Quickshell, Kitty, Cava, Rofi, SwayOSD, and SDDM.
- No manual theme editing required.

### Silent SDDM Login Greeter

- Animated video wallpapers (Rei, Ken, Silvia presets) with static image fallbacks.
- 16 built-in color presets: Catppuccin (Mocha, Latte, Frappe, Macchiato), Nord, Gruvbox, Everforest, Eldritch (Abyss, Cthulhu, Dusk), and more.
- Circular user avatar display, virtual keyboard, session selector, and power menu.
- Automatic Matugen accent color synchronization.

### Automated Installer

- Interactive TUI with `fzf` multi-select or traditional prompts.
- Safe backup of existing configurations before deployment.
- NVIDIA proprietary driver installation with kernel modesetting setup.
- Optional Neovim (with Lua LSP) and Zsh installation.
- Bundled wallpaper collection deployment.
- Systemd service enablement (NetworkManager, power-profiles-daemon).

---

## Installation

### Requirements

- **Operating System**: Arch Linux or an Arch-based distribution (CachyOS, EndeavourOS, Garuda, Manjaro, Parch).
- **Privileges**: `sudo` access for system package installation and display manager setup.
- **Internet**: Active connection for downloading packages.

### Clone and Install

```bash
git clone https://github.com/AnesuBlessed/hydra-linux.git
cd hydra-linux
chmod +x install.sh
./install.sh
```

The installer will guide you through component selection, install all dependencies, back up existing configs, deploy dotfiles, and configure SDDM. Log out or reboot when complete.

### Unattended Mode

Run with all recommended defaults and no prompts:

```bash
./install.sh -y
```

### Installer Flags

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Non-interactive mode with recommended defaults |
| `--skip-pkgs` | Deploy configs only, skip package installation |
| `--no-sddm` | Skip Silent SDDM greeter setup |
| `--with-nvim` | Include Neovim with Lua language server |
| `--with-zsh` | Include Zsh shell |
| `-h`, `--help` | Display usage information |

---

## Default Keybindings

### Window Management

| Keybinding | Action |
|------------|--------|
| `Super + Return` / `Super + Q` | Open terminal (Kitty) |
| `Super + C` | Close active window |
| `Super + V` | Toggle floating mode |
| `Super + F` | Toggle fullscreen |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split direction |
| `Super + Arrow Keys` | Move focus between windows |
| `Super + 1-9` | Switch to workspace 1-9 |
| `Super + Shift + 1-9` | Move active window to workspace 1-9 |
| `Super + Mouse Drag` | Move/resize windows |

### Applications

| Keybinding | Action |
|------------|--------|
| `Super + Space` / `Super + D` | Application launcher |
| `Super + E` | File manager |
| `Super + B` | Web browser (Firefox) |
| `Super + W` | Wallpaper picker |
| `Print` | Screenshot tool (Satty) |
| `Super + L` | Lock screen |
| `Super + M` | Logout / power menu |

### Media and System

| Keybinding | Action |
|------------|--------|
| `Volume Up/Down` | Adjust volume (SwayOSD) |
| `Volume Mute` | Toggle mute |
| `Brightness Up/Down` | Adjust screen brightness |
| `Media Play/Next/Prev` | Music player controls |

---

## Quickshell Widgets

All widgets are built with Qt6/QML and managed through the Quickshell shell runtime. They communicate via IPC through `qs_manager.sh`.

| Widget | Description |
|--------|-------------|
| **App Launcher** | Fuzzy-search application launcher with icon grid |
| **Battery** | Battery status, charge percentage, and power profile controls |
| **Calendar** | Monthly calendar with weather forecast integration (Open-Meteo) |
| **Clipboard** | Clipboard history manager powered by `cliphist` |
| **Focus Time** | Productivity timer with session tracking and statistics |
| **Guide** | Interactive onboarding tutorial with visual previews |
| **Monitors** | Display configuration and multi-monitor management |
| **Movies** | Media widget |
| **Music** | MPRIS music player with album art and Cava equalizer |
| **Network** | WiFi, Ethernet, and Bluetooth connection manager |
| **Notifications** | System notification popup handler |
| **Quick Actions** | Drawing tools, system usage monitor, and timer |
| **Settings** | Full settings panel: general, weather, keybinds, startup, avatar |
| **Stewart** | AI assistant integration widget |
| **Updater** | System update checker and notification panel |
| **Volume** | Audio device control with per-app volume and OSD |
| **Wallpaper** | Visual wallpaper picker with thumbnail carousel and web search |

---

## Silent SDDM Greeter

### Available Presets

Switch the active preset by editing `/usr/share/sddm/themes/silent/metadata.desktop`:

```ini
[SddmGreeterTheme]
ConfigFile=configs/rei.conf
```

| Preset | Style |
|--------|-------|
| `rei` | Animated (video wallpaper, default) |
| `ken` | Animated (video wallpaper) |
| `silvia` | Animated (video wallpaper) |
| `default` / `default-left` / `default-right` | Minimal static layouts |
| `catppuccin-mocha` | Catppuccin Mocha palette |
| `catppuccin-latte` | Catppuccin Latte palette |
| `catppuccin-frappe` | Catppuccin Frappe palette |
| `catppuccin-macchiato` | Catppuccin Macchiato palette |
| `nord` | Nord color scheme |
| `gruvbox` | Gruvbox color scheme |
| `everforest` | Everforest color scheme |
| `eldritch-abyss` | Eldritch Abyss dark theme |
| `eldritch-cthulhu` | Eldritch Cthulhu dark theme |
| `eldritch-dusk` | Eldritch Dusk dark theme |

---

## Customization

### Changing Wallpapers

Press `Super + W` to open the wallpaper picker. Select any image and Matugen will automatically regenerate colors across the entire desktop.

Wallpapers are stored in `~/Pictures/Wallpapers`. Drop new images into that directory and they will appear in the picker on the next launch.

### Profile Avatar

Run the avatar picker from Settings (General tab, Profile Avatar section) or from the terminal:

```bash
~/.config/hypr/scripts/set_avatar.sh
```

This opens a file chooser, center-crops the image to a circle, and deploys it to the login screen and desktop.

### Hyprland Configuration

Hyprland configs live in `~/.config/hypr/`. The Lua configuration files in `config/` are the primary source:

- `config/keybindings.lua` - Keyboard shortcuts
- `config/rules.lua` - Window rules and layer rules
- `config/monitors.lua` - Monitor layout and scaling
- `config/autostart.lua` - Startup applications
- `config/variables.lua` - General Hyprland settings
- `config/env.lua` - Environment variables

### Settings

The Quickshell settings panel (`Super + S` or click the gear icon) provides a GUI for configuring:

- General preferences (animations, blur, gaps, rounding)
- Weather location and units
- Keybind customization
- Startup application management
- Profile avatar

Settings are stored in `~/.config/hypr/settings.json`.

---

## Repository Structure

```
hydra-linux/
|-- .config/
|   |-- hypr/                  # Hyprland configuration
|   |   |-- hyprland.lua       # Main Lua entry point
|   |   |-- config/            # Modular Lua and Conf configs
|   |   |   |-- keybindings.lua
|   |   |   |-- rules.lua
|   |   |   |-- monitors.lua
|   |   |   |-- autostart.lua
|   |   |   |-- variables.lua
|   |   |   |-- env.lua
|   |   |   `-- settings.lua
|   |   |-- scripts/           # Shell scripts and Quickshell widgets
|   |   |   |-- quickshell/    # All QML widget source code
|   |   |   |-- qs_manager.sh  # Quickshell IPC manager
|   |   |   |-- caching.sh     # Cache path configuration
|   |   |   `-- set_avatar.sh  # Profile avatar utility
|   |   |-- settings.json      # User preferences
|   |   `-- default_settings.json
|   |-- kitty/                 # Kitty terminal config + Matugen colors
|   |-- cava/                  # Cava audio visualizer config
|   |-- matugen/               # Matugen color generation templates
|   |-- rofi/                  # Rofi launcher styling
|   |-- swayosd/               # SwayOSD volume/brightness overlay
|   `-- fastfetch/             # System info display config
|-- sddm/
|   |-- themes/silent/         # Silent SDDM theme
|   |   |-- Main.qml           # Theme entry point
|   |   |-- components/        # QML UI components
|   |   |-- configs/           # 16 color preset configs
|   |   |-- backgrounds/       # Video and static backgrounds
|   |   |-- fonts/             # RedHat font family
|   |   |-- icons/             # UI and session icons
|   |   `-- docs/              # Theme documentation and previews
|   `-- sddm.conf              # Display manager configuration
|-- .local/share/fonts/        # Bundled fonts (JetBrains Mono, Iosevka Nerd Font)
|-- assets/                    # Default profile avatar
|-- wallpapers/                # Starter wallpaper collection
|-- utils/                     # Utility wrappers (Cava theme injector)
|-- install.sh                 # Automated installer
|-- version.txt                # Current version (1.0.0)
|-- updates.json               # Update metadata
`-- LICENSE                    # GNU GPL v3.0
```

---

## Dependencies

The installer handles all dependencies automatically. For reference, the core packages include:

**Compositor and Shell**: hyprland, hypridle, quickshell-git, matugen-bin, swayosd-git, rofi, kitty

**Audio**: pipewire, wireplumber, pipewire-pulse, pamixer, playerctl, pavucontrol, easyeffects, cava

**Display Manager**: sddm, qt6-svg, qt6-virtualkeyboard, qt6-multimedia-ffmpeg

**Utilities**: grim, slurp, satty, imagemagick, wl-clipboard, cliphist, brightnessctl, inotify-tools, fastfetch, zenity

**Applications**: firefox, dolphin, nautilus

**Fonts**: JetBrains Mono, Iosevka Nerd Font, RedHat Display/Text/Mono

---

## Troubleshooting

### Wallpaper picker shows no images

Make sure your wallpapers are in `~/Pictures/Wallpapers`. The picker generates thumbnails on first launch, which may take a moment for large collections. If thumbnails are missing, press `Super + W` again to trigger regeneration.

### SDDM not loading the theme

Verify the theme is installed and the config points to it:

```bash
cat /etc/sddm.conf | grep Theme
# Should show: Current=silent
```

If SDDM was not enabled, run:

```bash
sudo systemctl enable sddm.service -f
```

### Matugen colors not applying

Ensure `matugen` is installed and the wallpaper path is valid. Matugen runs automatically when a new wallpaper is selected through the picker.

### Audio not working

Check that PipeWire services are running:

```bash
systemctl --user status pipewire wireplumber
```

---

## Acknowledgments

### Serpantinum

The Quickshell desktop shell in Hydra Linux is built on [Serpantinum](https://github.com/ilyamiro/serpantinum) by [ilyamiro](https://github.com/ilyamiro). Serpantinum provides the foundational QML widget architecture, IPC system, and overall shell design for Wayland compositors. The original look and feel has been intentionally preserved because the design is already clean, functional, and well-suited for a daily-driver desktop. Rather than redesigning for the sake of it, Hydra Linux focuses on extending the shell with additional features, deeper system integration, and a unified installer experience.

### Silent SDDM

The login greeter included in Hydra Linux is based on [Silent SDDM](https://github.com/uiriansan/SilentSDDM) by [uiriansan](https://github.com/uiriansan). It provides the animated video wallpaper support, multiple color presets, and the modular QML architecture that powers the greeter experience.

For standalone installation or more information about Silent SDDM, visit their repository:

```bash
git clone -b main --depth=1 https://github.com/uiriansan/SilentSDDM
cd SilentSDDM
./install.sh
```

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
