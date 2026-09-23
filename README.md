<div align="center">

```
██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
███████║ ╚████╔╝ ██║  ██║██████╔╝███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
```

# 🐉 Hydra Linux

<div align="center">
  <img src="https://img.shields.io/badge/Hyprland-Dynamic%20Tiling-blue?style=for-the-badge&logo=hyprland&logoColor=white" />
  <img src="https://img.shields.io/badge/Quickshell-Desktop%20UI-purple?style=for-the-badge&logo=qt&logoColor=white" />
  <img src="https://img.shields.io/badge/Matugen-Dynamic%20Colors-orange?style=for-the-badge&logo=materialdesign&logoColor=white" />
  <img src="https://img.shields.io/badge/Arch_Linux-Native-1793d1?style=for-the-badge&logo=arch-linux&logoColor=white" />
  <img src="https://img.shields.io/badge/License-GPL_3.0-green?style=for-the-badge" />
</div>

<br>

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

### Modular Hyprland Configuration

- Dual configuration architecture: Standard (`hyprland.conf`, `config/*.conf`) and Lua-native (`hyprland.lua`, `config/*.lua`) for CachyOS and Lua-enabled Hyprland builds.
- Dynamic GPU detection (NVIDIA, AMD, Intel) with automatic driver configuration.
- Comprehensive keybinding system with workspace management, window rules, and multi-monitor support.

### Quickshell Desktop Shell

A full-featured Qt6/QML desktop shell with interactive widgets, all fully UI-scale aware:

- **Top bar** with system tray, clock, workspace indicators, media controls, weather, and status pills.
- **Application launcher** with fuzzy search and icon grid.
- **Dynamic wallpaper picker** with thumbnail previews and DuckDuckGo image search.
- **Calendar** with integrated weather forecasts (Open-Meteo API, no API key required).
- **Network manager** with WiFi, Ethernet, and Bluetooth panels.
- **Music player** with album art, progress tracking, and equalizer visualization.
- **Volume and brightness controls** with OSD overlays via SwayOSD.
- **Battery monitor** with power profile switching.
- **Focus time tracker** with session statistics.
- **Clipboard manager** with full history, per-item delete, and one-click wipe.
- **Notification system** with inline action buttons and typewriter animations.
- **System settings panel** (General, Keybinds, Startup Apps).
- **SDDM video manager** — change the login screen background video from within the settings panel.
- **Profile avatar manager** — set your login and desktop avatar with automatic cropping.
- **Monitor management** and display configuration.
- **Interactive guide/tutorial** system for new users.

### Matugen Dynamic Theming

- Set any wallpaper and Matugen automatically generates a system-wide color palette.
- Colors propagate in real-time to Quickshell, Kitty, Cava, Rofi, SwayOSD, and Silent SDDM.
- No manual theme editing required.

### Silent SDDM Login Greeter

- Animated video wallpapers (Rei, Ken, Silvia presets) with static image fallbacks.
- **Change the login video directly from the Quickshell settings panel** — no manual config editing needed.
- Built-in color presets: Catppuccin (Mocha, Latte, Frappe, Macchiato), Nord, Gruvbox, Everforest, Eldritch (Abyss, Cthulhu, Dusk), and more.
- Circular user avatar display, virtual keyboard, session selector, and power menu.
- Automatic Matugen accent color synchronization.

### Automated Installer

- Clean, zero-dependency interactive installer with native ANSI styling and unattended `-y` mode.
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
| `Super + Q` | Close active window |
| `Super + Shift + F` | Toggle floating mode |
| `Super + Shift + Arrows` | Resize active window |
| `Super + Ctrl + Arrows` | Move window directionally |
| `Super + Arrows` | Move focus between windows |
| `Super + 1-9` | Switch to workspace 1-9 |
| `Super + Shift + 1-9` | Move active window to workspace 1-9 |
| `Super + Backspace` | Toggle Pocket Dimension (special scratchpad workspace) |
| `Super + Shift + Backspace` | Move active window to Pocket Dimension |
| `Super + Mouse Left Drag` | Move window |
| `Super + Mouse Right Drag` | Resize window |

### Applications & Shell Panels

| Keybinding | Action |
|------------|--------|
| `Super + T` | Open terminal (Kitty) |
| `Super + F` | Web browser (Firefox) |
| `Super + E` | File manager (Dolphin) |
| `Super + A` | Application launcher |
| `Super + W` | Wallpaper picker |
| `Super + C` | Clipboard manager |
| `Super + S` | Calendar & weather popup |
| `Super + Shift + S` | Settings panel (General, Keybinds, Startup) |
| `Super + N` | Network manager (WiFi, Ethernet, Bluetooth) |
| `Super + M` | Music player panel |
| `Super + B` | Battery & power profile popup |
| `Super + V` | Audio device & volume panel |
| `Super + P` | Anime Player (stream anime with `ani-cli` in `mpv`) |
| `Super + H` | Interactive user guide |
| `Super + Shift + T` | Focus time productivity tracker |
| `Super + R` | Reload shell & desktop scripts |
| `Super + L` / `Power` | Lock screen |

### Media & System Controls

| Keybinding | Action |
|------------|--------|
| `Print` | Interactive screenshot (Satty) |
| `Shift + Print` | Interactive screenshot with editor |
| `Super + Print` | Fullscreen screenshot |
| `Volume Up/Down` | Adjust output volume (SwayOSD) |
| `Volume Mute` | Toggle output mute (SwayOSD) |
| `Mic Mute` | Toggle microphone mute |
| `Brightness Up/Down` | Adjust screen brightness (SwayOSD) |
| `Super + Space` / `Media Play` | Music play / pause toggle |
| `Caps Lock` | Caps lock status indicator (SwayOSD) |

---

## Quickshell Widgets

All widgets are built with Qt6/QML and managed through the Quickshell shell runtime. They communicate via IPC through `qs_manager.sh`. Every widget is UI-scale aware and adapts automatically to your display scaling factor.

| Widget | Description |
|--------|-------------|
| **App Launcher** | Fuzzy-search application launcher with icon grid |
| **Battery** | Battery status, charge percentage, and power profile controls |
| **Calendar** | Monthly calendar with weather forecast integration (Open-Meteo) |
| **Clipboard** | Clipboard history manager powered by `cliphist` — with per-item delete and full wipe |
| **Focus Time** | Productivity timer with session tracking and statistics |
| **Guide** | Interactive onboarding tutorial with visual previews |
| **Monitors** | Display configuration and multi-monitor management |
| **Music** | MPRIS music player with album art and EasyEffects equalizer |
| **Network** | WiFi, Ethernet, and Bluetooth connection manager |
| **Notifications** | System notification popup handler with inline action buttons |
| **Quick Actions** | Drawing tools, system usage monitor, and timer |
| **Settings** | Full settings panel: general, keybinds, startup, avatar, SDDM video |
| **Updater** | System update checker and notification panel |
| **Volume** | Audio device control with per-app volume and OSD |
| **Wallpaper** | Visual wallpaper picker with thumbnail carousel and web search |

---

## Silent SDDM Greeter

### Changing the Login Video

The easiest way is through the Quickshell settings panel:

1. Open Settings (gear icon in the top bar or `Super + Shift + S`).
2. Go to the **General** tab.
3. Scroll to **SDDM Login Video**.
4. Click **Browse…** to pick any video file, or drop a video into `/usr/share/sddm/themes/silent/backgrounds/`.
5. The built-in presets (Rei, Ken, Silvia) appear as options automatically.

### Available Presets

Switch the active preset manually by editing `/usr/share/sddm/themes/silent/metadata.desktop`:

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

Wallpapers are stored in `~/Pictures/Wallpapers`. Drop new images into that directory and they appear in the picker on the next launch.

### Profile Avatar

Open Settings → General → **Profile Avatar**, then click **Browse…** to pick any image. It is automatically center-cropped to a circle and deployed to both the login screen and the desktop shell.

You can also run it from the terminal:

```bash
~/.config/hypr/scripts/set_avatar.sh
```

### SDDM Login Video

Open Settings → General → **SDDM Login Video**, then click **Browse…** to pick any `.mp4` file. Drop additional videos into `/usr/share/sddm/themes/silent/backgrounds/` and they appear as options immediately.

### UI Scale

The entire shell respects a single `uiScale` value in `~/.config/hypr/settings.json`. Change it in Settings → General → **UI Scale** slider. All widgets, icons, and spacing scale proportionally.

### Settings Panel

The settings panel (`Super + S` or click the ⚙ icon) provides a GUI for:

- **General** — UI scale, help icon toggle, workspace count, profile avatar, SDDM video
- **Keybinds** — Full keybind editor, add/edit/remove bindings
- **Startup** — Manage autostart applications

Settings are stored in `~/.config/hypr/settings.json` and applied immediately without restarting.

### Hyprland Configuration

Hyprland configs live in `~/.config/hypr/`. The modular config files in `config/` are the primary source of truth:

- `config/keybindings.conf` — Keyboard shortcuts
- `config/rules.conf` — Window rules and layer rules
- `config/monitors.conf` — Monitor layout and scaling
- `config/autostart.conf` — Startup applications (auto-generated from settings.json)
- `config/variables.conf` — General Hyprland settings
- `config/env.conf` — Environment variables (auto-generated)

---

## Repository Structure

```
hydra-linux/
├── .config/
│   ├── hypr/                    # Hyprland configuration
│   │   ├── hyprland.conf        # Main entry point (standard Hyprland)
│   │   ├── hyprland.lua         # Lua entry point (CachyOS / Lua-enabled Hyprland)
│   │   ├── config/              # Modular configs (.conf and .lua)
│   │   │   ├── keybindings.conf / keybindings.lua
│   │   │   ├── rules.conf / rules.lua
│   │   │   ├── monitors.conf / monitors.lua
│   │   │   ├── autostart.conf / autostart.lua
│   │   │   ├── variables.conf / variables.lua
│   │   │   └── env.conf / env.lua
│   │   ├── scripts/             # Shell scripts and Quickshell widgets
│   │   │   ├── quickshell/      # All QML widget source code
│   │   │   │   ├── Shell.qml    # Quickshell entry point
│   │   │   │   ├── TopBar.qml   # Top bar (clock, workspaces, tray)
│   │   │   │   ├── SysData.qml  # Singleton: CPU/RAM/temp data provider
│   │   │   │   ├── Config.qml   # Singleton: settings.json reader/writer
│   │   │   │   ├── watchers/    # Event-driven data scripts (inotifywait pattern)
│   │   │   │   ├── settings/    # Settings popup panel
│   │   │   │   ├── clipboard/   # Clipboard history manager
│   │   │   │   ├── calendar/    # Calendar + weather widget
│   │   │   │   ├── music/       # MPRIS music player
│   │   │   │   ├── network/     # WiFi/BT/Ethernet panel
│   │   │   │   ├── wallpaper/   # Wallpaper picker
│   │   │   │   └── ...          # Other widgets
│   │   │   ├── qs_manager.sh    # Quickshell IPC manager
│   │   │   ├── caching.sh       # Cache/run path configuration
│   │   │   ├── set_avatar.sh    # Profile avatar utility
│   │   │   ├── set_sddm_video.sh # SDDM login video setter
│   │   │   └── settings_watcher.sh # Watches settings.json → rebuilds configs
│   │   ├── templates/           # Config templates (populated by settings_watcher)
│   │   └── settings.json        # User preferences (source of truth)
│   ├── kitty/                   # Kitty terminal config + Matugen colors
│   ├── cava/                    # Cava audio visualizer config
│   ├── matugen/                 # Matugen color generation templates
│   ├── rofi/                    # Rofi launcher styling
│   ├── swayosd/                 # SwayOSD volume/brightness overlay
│   └── fastfetch/               # System info display config
├── sddm/
│   ├── themes/silent/           # Silent SDDM theme
│   │   ├── Main.qml             # Theme entry point
│   │   ├── components/          # QML UI components
│   │   ├── configs/             # Built-in color preset configs
│   │   ├── backgrounds/         # Video and static backgrounds
│   │   ├── fonts/               # RedHat font family
│   │   └── icons/               # UI and session icons
│   └── sddm.conf                # Display manager configuration
├── assets/                      # Default profile avatar and branding
├── wallpapers/                  # Starter wallpaper collection
├── utils/                       # Utility wrappers
├── install.sh                   # Automated installer
├── version.txt                  # Current version
├── updates.json                 # Update metadata
└── LICENSE                      # GNU GPL v3.0
```

---

## Architecture Notes

### How the Shell Communicates

All widget open/close/toggle actions go through `qs_manager.sh`, which routes IPC calls to the running Quickshell process:

```bash
~/.config/hypr/scripts/qs_manager.sh toggle settings
~/.config/hypr/scripts/qs_manager.sh toggle clipboard
~/.config/hypr/scripts/qs_manager.sh toggle calendar
```

### How Settings Are Applied

`settings.json` is the single source of truth. `settings_watcher.sh` watches it with `inotifywait` and rebuilds all Hyprland config files from templates whenever it changes. No manual `hyprctl reload` is needed — it happens automatically.

### How Data Watchers Work

All live data (audio, battery, network, Bluetooth, keyboard layout) uses an event-driven pattern:

1. A **fetcher** script reads the current state and outputs JSON.
2. A **waiter** script blocks on `inotifywait` or `udevadm`/`nmcli monitor` until a hardware event fires.
3. When the waiter exits, QML re-runs the fetcher and restarts the waiter.

This means **zero polling overhead** when nothing is changing.

### Security & Hardening Architecture

Hydra Linux enforces strict defense-in-depth principles across its glue scripts:
- **No Arbitrary State Sourcing**: Version information is parsed safely via `hydra_version.sh` rather than sourcing shell files.
- **Isolated User Runtimes**: All transient files, locks, FIFOs, and logs reside under `$XDG_RUNTIME_DIR/quickshell` (permissions `0700`) via `caching.sh`, preventing `/tmp` shared symlink attacks.
- **User-Scoped Process Management**: All background watcher signals and checks (`pgrep`, `pkill`) are strictly scoped to the active `$UID`.
- **Parameterization Over Interpolation**: Privileged operations (`pkexec`) avoid arbitrary string evaluation (`eval`), utilizing strict argument passing and `install` commands.

### CPU/RAM/Temperature

`SysData.qml` is a singleton that reads CPU, RAM, and temperature every 2 seconds only when at least one widget has subscribed (called `subscribe()`). When all widgets close it stops automatically. Theme colors are monitored using direct `inotifywait` kernel notifications on `qs_colors.json`, keeping background idle CPU utilization close to 0%.

---

## Dependencies

The installer handles all dependencies automatically. For reference, the core packages include:

**Compositor and Shell**: `hyprland`, `hypridle`, `quickshell-git`, `matugen-bin`, `swayosd-git`, `rofi`, `kitty`

**Audio**: `pipewire`, `wireplumber`, `pipewire-pulse`, `pamixer`, `playerctl`, `pavucontrol`, `easyeffects`, `cava`

**Display Manager**: `sddm`, `qt6-svg`, `qt6-virtualkeyboard`, `qt6-multimedia-ffmpeg`

**Utilities**: `grim`, `slurp`, `satty`, `imagemagick`, `wl-clipboard`, `cliphist`, `brightnessctl`, `inotify-tools`, `fastfetch`, `zenity`, `pkexec`

**Applications**: `firefox`, `dolphin`

**Fonts**: JetBrains Mono, Iosevka Nerd Font, RedHat Display/Text/Mono

---

## Troubleshooting

### Quickshell not showing / top bar missing after login

The bar is launched by Hyprland autostart via `autostart.conf`. If it fails to start:

```bash
# Restart manually with dynamic socket detection
WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="/run/user/$(id -u)" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
  quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml &
```

Or use the IPC manager:

```bash
~/.config/hypr/scripts/qs_manager.sh reload
```

### Wallpaper picker shows no images

Make sure your wallpapers are in `~/Pictures/Wallpapers`. The picker generates thumbnails on first launch — press `Super + W` again if thumbnails are missing.

### SDDM not loading the theme

Verify the theme is installed and the config points to it:

```bash
cat /etc/sddm.conf | grep Theme
# Should show: Current=silent

sudo systemctl enable sddm.service -f
```

### Matugen colors not applying

Ensure `matugen` is installed and the wallpaper path is valid. Matugen runs automatically when a wallpaper is selected through the picker.

### Audio not working

Check that PipeWire services are running:

```bash
systemctl --user status pipewire wireplumber
```

### Settings panel tabs not highlighting correctly

This was fixed in v1.0.1. If you see the wrong tab highlighted, pull the latest version and reload Quickshell:

```bash
git pull
~/.config/hypr/scripts/qs_manager.sh reload
```

---

## Acknowledgments

### Serpantinum

The Quickshell desktop shell in Hydra Linux is built on [Serpantinum](https://github.com/ilyamiro/serpantinum) by [ilyamiro](https://github.com/ilyamiro). Serpantinum provides the foundational QML widget architecture, IPC system, and overall shell design for Wayland compositors. Rather than redesigning for the sake of it, Hydra Linux extends the shell with additional features, deeper system integration, and a unified installer.

### Silent SDDM

The login greeter is based on [Silent SDDM](https://github.com/uiriansan/SilentSDDM) by [uiriansan](https://github.com/uiriansan). It provides the animated video wallpaper support, multiple color presets, and the modular QML architecture that powers the greeter.

```bash
git clone -b main --depth=1 https://github.com/uiriansan/SilentSDDM
cd SilentSDDM
./install.sh
```

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
