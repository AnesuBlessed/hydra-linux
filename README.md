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

### Complete, Unified Hyprland & Silent SDDM Desktop Suite

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20CachyOS-1793d1.svg?logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Compositor: Hyprland](https://img.shields.io/badge/Compositor-Hyprland%20(Lua)-00c853.svg)](https://hyprland.org/)
[![Shell: Quickshell](https://img.shields.io/badge/Shell-Quickshell%20(Qt6)-673ab7.svg)](https://github.com/outfoxxed/quickshell)
[![Display Manager: Silent SDDM](https://img.shields.io/badge/Greeter-Silent%20SDDM%20(Animated)-e91e63.svg)](sddm/)

</div>

---

## 🌟 Overview

**Hydra Linux** is a complete, pre-configured desktop environment combining **Hyprland** with full modular **Lua** configuration support, the **Quickshell** desktop shell, **Matugen** dynamic color generation, and the **Silent SDDM** login greeter with animated video wallpapers.

Unlike minimal dotfiles or decoupled desktop shells, **Hydra Linux** comes as a unified, complete distribution package with an automated installer that handles everything from system dependencies to display manager setup out of the box.

---

## ✨ Features

- **Dual-Engine Hyprland Config (Lua & Conf)**:
  - First-class native Lua configuration (`hyprland.lua`, `config/*.lua`) providing type safety, modular design, and programmatic customization alongside traditional `.conf` files.
- **Silent SDDM with Animated Wallpapers**:
  - Pre-packaged with Silent SDDM greeter featuring animated video wallpapers (`rei.mp4`, `ken.mp4`, `silvia.mp4`), virtual keyboard, and multiple color themes.
- **Dynamic Theming via Matugen**:
  - Wallpapers automatically generate system-wide color palettes that update Quickshell, Kitty, Cava, Rofi, and SwayOSD in real-time.
- **Quickshell Desktop Suite**:
  - Sleek topbar, interactive application launcher, control center, calendar & weather popup, wallpaper selector, and audio/brightness OSD.
- **Automated Installer**:
  - Interactive TUI installer (`install.sh`) with dependency checks, GPU detection, safe backups, font deployment, and service configuration.

---

## 🚀 Installation

### Prerequisites
- **OS**: Arch Linux or any Arch-based distribution (CachyOS, EndeavourOS, Garuda, etc.)
- Working internet connection and `sudo` privileges.

### Quick Install

Clone the repository and run the installer:

```bash
git clone https://github.com/hydra-linux/hydra-linux.git
cd hydra-linux
chmod +x install.sh
./install.sh
```

### Unattended / Batch Mode

To run with default settings and no interactive prompts:

```bash
./install.sh -y
```

### Installer Options

| Flag | Description |
|------|-------------|
| `-y`, `--yes` | Run non-interactively with recommended defaults |
| `--skip-pkgs` | Deploy dotfiles, fonts, and SDDM without running `pacman`/`yay` |
| `--no-sddm` | Skip Silent SDDM greeter installation |
| `--with-nvim` | Install Neovim with Lua language server |
| `--with-zsh` | Install Zsh shell |
| `-h`, `--help` | Display help message |

---

## ⌨️ Default Keybindings

| Keybinding | Action |
|------------|--------|
| `Super + Return` / `Super + Q` | Open Kitty Terminal |
| `Super + Space` / `Super + D` | Open App Launcher |
| `Super + W` | Open Dynamic Wallpaper Picker |
| `Super + C` | Close Active Window |
| `Super + M` | Exit / Logout Menu |
| `Super + E` | Open File Manager (Nautilus) |
| `Super + V` | Toggle Floating Window |
| `Super + F` | Toggle Fullscreen |
| `Print` | Interactive Screenshot Tool (Satty) |
| `Super + L` | Lock Screen |

---

## 📁 Repository Structure

```
hydra-linux/
├── .config/
│   ├── hypr/               # Hyprland modular Lua & Conf configs, Quickshell widgets, scripts
│   ├── quickshell/         # Quickshell desktop shell configs
│   ├── kitty/              # Kitty terminal config + Matugen color schemes
│   ├── cava/               # Cava audio visualizer configs
│   ├── matugen/            # Matugen templates & dynamic color rules
│   ├── rofi/               # Rofi app launcher styling
│   ├── swayosd/            # SwayOSD styling
│   └── fastfetch/          # Fastfetch configuration
├── sddm/
│   ├── themes/silent/      # Silent SDDM theme (QML, presets, video backgrounds, fonts)
│   └── sddm.conf           # SDDM greeter configuration template
├── .local/share/fonts/     # Pre-packaged fonts (JetBrains Mono, Iosevka Nerd Font, RedHat)
├── wallpapers/             # Showcase wallpaper collection
├── utils/                  # Wrapper utilities (cava dynamic theme injector)
├── install.sh              # Automated TUI installer script
├── updates.json            # Version and update descriptor
├── version.txt             # Current release version
├── LICENSE                 # GNU General Public License v3.0
└── README.md               # Documentation
```

---

## 🎨 Customizing Silent SDDM

Silent SDDM comes with multiple built-in presets. You can switch presets by editing `/usr/share/sddm/themes/silent/metadata.desktop`:

```ini
[SddmGreeterTheme]
# Active preset:
ConfigFile=configs/rei.conf
# Other available options:
# ConfigFile=configs/default.conf
# ConfigFile=configs/ken.conf
# ConfigFile=configs/silvia.conf
# ConfigFile=configs/catppuccin-mocha.conf
# ConfigFile=configs/nord.conf
```

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
