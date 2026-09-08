#!/usr/bin/env bash

# ==============================================================================
#
#   ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
#   ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
#   ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
#   ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
#   ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
#   ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
#
#   Hydra Linux - Unified Hyprland, Quickshell & Silent SDDM Environment
#   Installer & System Deployment Script
#
# ==============================================================================

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="1.0.0"
VERSION_FILE="$HOME/.local/state/hydra-linux-version"

# Colors & UI
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
C_BLUE="\e[34m"
C_CYAN="\e[36m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_MAGENTA="\e[35m"

draw_header() {
    clear
    echo -e "${C_CYAN}"
    echo "  ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗"
    echo "  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝"
    echo "  ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ "
    echo "  ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ "
    echo "  ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗"
    echo "  ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${RESET}"
    echo -e "         ${BOLD}${C_MAGENTA}Hydra Linux Desktop Suite${RESET}  ${DIM}|${RESET}  ${C_BLUE}Version ${HYDRA_VERSION}${RESET}"
    echo -e "   ${DIM}Hyprland (Lua + Conf) • Quickshell • Matugen • Silent SDDM${RESET}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# --- 1. Distro Detection ---
if [ -f /etc/os-release ]; then
    DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
else
    echo -e "${C_RED}Cannot detect OS. /etc/os-release not found.${RESET}"
    exit 1
fi

case "$DETECTED_OS" in
    arch|cachyos|endeavouros|garuda|manjaro|parch)
        ;;
    *)
        echo -e "${C_RED}Unsupported distribution: '$DETECTED_OS'${RESET}"
        echo -e "${C_YELLOW}Hydra Linux currently targets Arch Linux and Arch-based systems (CachyOS, EndeavourOS, etc.).${RESET}"
        exit 1
        ;;
esac

# Prevent TTY screen blanking during package compilation
setterm -blank 0 -powerdown 0 2>/dev/null || true
printf '\033[9;0]' 2>/dev/null || true

# Parse Command-line Arguments
UNATTENDED=false
SKIP_PKGS=false
INSTALL_SDDM=true
INSTALL_NVIM=false
INSTALL_ZSH=false
INSTALL_WALLPAPERS=true

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -y|--yes|--unattended) UNATTENDED=true; shift ;;
        --skip-pkgs) SKIP_PKGS=true; shift ;;
        --no-sddm) INSTALL_SDDM=false; shift ;;
        --with-nvim) INSTALL_NVIM=true; shift ;;
        --with-zsh) INSTALL_ZSH=true; shift ;;
        -h|--help)
            echo "Hydra Linux Installer"
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  -y, --yes          Run non-interactively with defaults"
            echo "  --skip-pkgs        Skip package installation phase"
            echo "  --no-sddm          Skip SDDM theme installation"
            echo "  --with-nvim        Install Neovim with Lua language server"
            echo "  --with-zsh         Install Zsh shell"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# User paths
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"

# Hardware / GPU detection
GPU_VENDOR="Unknown"
GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
if echo "$GPU_RAW" | grep -qi "nvidia"; then
    GPU_VENDOR="NVIDIA"
elif echo "$GPU_RAW" | grep -qi "amd\|advanced micro devices"; then
    GPU_VENDOR="AMD"
elif echo "$GPU_RAW" | grep -qi "intel"; then
    GPU_VENDOR="Intel"
fi

# Bootstrap minimal prerequisites
if ! command -v fzf &>/dev/null || ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    echo -e "${C_CYAN}[ INFO ] Bootstrapping installer dependencies (fzf, jq, curl)...${RESET}"
    sudo pacman -Sy --noconfirm --needed fzf jq curl >/dev/null 2>&1 || true
fi

# Check for AUR Helper
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo -e "${C_CYAN}[ INFO ] Installing 'yay' (AUR helper)...${RESET}"
    sudo pacman -S --noconfirm --needed base-devel git
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin >/dev/null 2>&1
    (cd /tmp/yay-bin && makepkg -si --noconfirm >/dev/null 2>&1)
    rm -rf /tmp/yay-bin
fi

if command -v yay &>/dev/null; then
    PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &>/dev/null; then
    PKG_MANAGER="paru -S --noconfirm --needed"
else
    PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

# Package Lists
CORE_PKGS=(
    # Compositor & Shell
    "hyprland" "hypridle" "hyprpolkitagent" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "quickshell-git" "matugen-bin" "swayosd-git" "rofi" "kitty" "cava" "fastfetch"
    # Silent SDDM & dependencies
    "sddm" "qt6-svg" "qt6-virtualkeyboard" "qt6-multimedia-ffmpeg" "qt6-imageformats"
    # Audio & Media
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "libpulse" "pamixer" "playerctl" "pavucontrol" "alsa-utils" "easyeffects" "lsp-plugins"
    # Screen capture & Utilities
    "grim" "slurp" "satty" "awww" "mpvpaper" "gpu-screen-recorder" "nwg-displays"
    "wl-clipboard" "cliphist" "jq" "yq" "socat" "inotify-tools" "brightnessctl" "acpi" "iw" "lm_sensors" "bc" "imagemagick" "wget" "file" "git" "psmisc" "unzip" "fd" "ripgrep" "power-profiles-daemon" "nautilus"
    # Qt / GTK engines
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland" "qt5ct" "qt6ct" "adw-gtk-theme" "qt6-5compat" "qt6-websockets" "python-websockets"
)

DRIVER_PKGS=()

# Interactive Menu if not unattended
if [ "$UNATTENDED" = false ]; then
    draw_header
    echo -e "${BOLD}Detected System:${RESET} $OS_PRETTY"
    echo -e "${BOLD}Detected GPU:${RESET}    $GPU_VENDOR\n"

    # Interactive TUI choices
    if command -v fzf &>/dev/null; then
        echo -e "${C_CYAN}Select installation components (TAB or SPACE to toggle, ENTER to confirm):${RESET}\n"
        CHOICES=$(printf "Silent SDDM Greeter & Animated Wallpapers\nWallpapers Collection\nNeovim with Lua Language Server\nZsh Shell\nSkip Package Installation (Deploy Configs Only)\n" | fzf -m --prompt="Hydra Linux > " --pointer="▶" --header="Options")
        
        if echo "$CHOICES" | grep -q "Silent SDDM"; then INSTALL_SDDM=true; else INSTALL_SDDM=false; fi
        if echo "$CHOICES" | grep -q "Wallpapers Collection"; then INSTALL_WALLPAPERS=true; else INSTALL_WALLPAPERS=false; fi
        if echo "$CHOICES" | grep -q "Neovim"; then INSTALL_NVIM=true; fi
        if echo "$CHOICES" | grep -q "Zsh"; then INSTALL_ZSH=true; fi
        if echo "$CHOICES" | grep -q "Skip Package Installation"; then SKIP_PKGS=true; fi
    else
        read -p "Install Silent SDDM Greeter & Animated Wallpapers? [Y/n]: " ans_sddm
        [[ "$ans_sddm" =~ ^[Nn]$ ]] && INSTALL_SDDM=false

        read -p "Install bundled wallpapers? [Y/n]: " ans_wp
        [[ "$ans_wp" =~ ^[Nn]$ ]] && INSTALL_WALLPAPERS=false

        read -p "Install Neovim with Lua support? [y/N]: " ans_nvim
        [[ "$ans_nvim" =~ ^[Yy]$ ]] && INSTALL_NVIM=true

        read -p "Install Zsh? [y/N]: " ans_zsh
        [[ "$ans_zsh" =~ ^[Yy]$ ]] && INSTALL_ZSH=true
    fi

    # GPU Driver Option
    if [ "$GPU_VENDOR" == "NVIDIA" ]; then
        read -p "Install NVIDIA proprietary drivers and configure kernel modesetting? [y/N]: " ans_gpu
        if [[ "$ans_gpu" =~ ^[Yy]$ ]]; then
            DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")
        fi
    fi
fi

# Append optional packages
[[ "$INSTALL_NVIM" = true ]] && CORE_PKGS+=("neovim" "lua-language-server" "nodejs" "npm" "python3")
[[ "$INSTALL_ZSH" = true ]] && CORE_PKGS+=("zsh")

# ==============================================================================
# Phase 1: Package Installation
# ==============================================================================
if [ "$SKIP_PKGS" = false ]; then
    echo -e "\n${C_CYAN}[ INFO ]${RESET} Checking missing packages..."
    ALL_PKGS=("${CORE_PKGS[@]}" "${DRIVER_PKGS[@]}")
    MISSING_PKGS=()

    for pkg in "${ALL_PKGS[@]}"; do
        [[ -z "$pkg" ]] && continue
        if ! pacman -Q "$pkg" &>/dev/null; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        echo -e "  -> ${C_GREEN}All required packages are already installed!${RESET}"
    else
        echo -e "  -> ${C_YELLOW}Found ${#MISSING_PKGS[@]} packages to install:${RESET} ${MISSING_PKGS[*]}"
        SAFE_JOBS=$(( $(nproc) / 2 ))
        [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
        [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4

        for pkg in "${MISSING_PKGS[@]}"; do
            echo -e "\n${C_BLUE}::${RESET} Installing ${BOLD}${pkg}${RESET}..."
            if yes "Y" 2>/dev/null | env CARGO_BUILD_JOBS="$SAFE_JOBS" MAKEFLAGS="-j$SAFE_JOBS" $PKG_MANAGER "$pkg"; then
                echo -e "  -> ${C_GREEN}[ OK ] Installed ${pkg}${RESET}"
            else
                echo -e "  -> ${C_RED}[ FAILED ] Could not install ${pkg}, continuing...${RESET}"
            fi
        done
    fi
fi

# ==============================================================================
# Phase 2: Configuration Backup
# ==============================================================================
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/hydra_backup/backup_${BACKUP_DATE}"

echo -e "\n${C_CYAN}[ INFO ]${RESET} Creating backup of existing configurations..."
mkdir -p "$BACKUP_DIR"

CONFIGS_TO_DEPLOY=("hypr" "quickshell" "kitty" "cava" "matugen" "rofi" "swayosd" "fastfetch")

for cfg in "${CONFIGS_TO_DEPLOY[@]}"; do
    if [ -d "$HOME/.config/$cfg" ] || [ -f "$HOME/.config/$cfg" ]; then
        cp -rf "$HOME/.config/$cfg" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done
echo -e "  -> ${C_GREEN}[ OK ] Existing configs backed up to:${RESET} $BACKUP_DIR"

# ==============================================================================
# Phase 3: Dotfiles Deployment
# ==============================================================================
echo -e "\n${C_CYAN}[ INFO ]${RESET} Deploying Hydra Linux dotfiles..."
mkdir -p "$HOME/.config" "$HOME/.local/bin"

for cfg in "${CONFIGS_TO_DEPLOY[@]}"; do
    if [ -d "$SCRIPT_DIR/.config/$cfg" ]; then
        rm -rf "$HOME/.config/$cfg"
        cp -r "$SCRIPT_DIR/.config/$cfg" "$HOME/.config/"
        echo -e "  -> ${C_GREEN}[ OK ] Deployed ~/.config/${cfg}${RESET}"
    fi
done

# Deploy utility cava wrapper
if [ -f "$SCRIPT_DIR/utils/bin/cava" ]; then
    cp -f "$SCRIPT_DIR/utils/bin/cava" "$HOME/.local/bin/cava"
    chmod +x "$HOME/.local/bin/cava"
fi

# Ensure all scripts are executable
if [ -d "$HOME/.config/hypr/scripts" ]; then
    find "$HOME/.config/hypr/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# Initial template compile
if [ -f "$HOME/.config/hypr/scripts/settings_watcher.sh" ]; then
    echo -e "  -> Compiling configuration templates..."
    bash "$HOME/.config/hypr/scripts/settings_watcher.sh" --compile >/dev/null 2>&1 || true
fi

# ==============================================================================
# Phase 4: Fonts & Wallpapers
# ==============================================================================
echo -e "\n${C_CYAN}[ INFO ]${RESET} Installing fonts and assets..."
mkdir -p "$HOME/.local/share/fonts"
if [ -d "$SCRIPT_DIR/.local/share/fonts" ]; then
    cp -rn "$SCRIPT_DIR/.local/share/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null || true
fi
fc-cache -fv >/dev/null 2>&1 || true
echo -e "  -> ${C_GREEN}[ OK ] Fonts deployed and font cache updated.${RESET}"

if [ "$INSTALL_WALLPAPERS" = true ]; then
    mkdir -p "$WALLPAPER_DIR"
    if [ -d "$SCRIPT_DIR/wallpapers" ]; then
        cp -rn "$SCRIPT_DIR/wallpapers/"* "$WALLPAPER_DIR/" 2>/dev/null || true
    fi
    echo -e "  -> ${C_GREEN}[ OK ] Showcase wallpapers deployed to:${RESET} $WALLPAPER_DIR"
fi

# ==============================================================================
# Phase 5: Silent SDDM Installation & Configuration
# ==============================================================================
if [ "$INSTALL_SDDM" = true ] && [ -d "$SCRIPT_DIR/sddm/themes/silent" ]; then
    echo -e "\n${C_CYAN}[ INFO ]${RESET} Configuring Silent SDDM theme..."
    sudo mkdir -p /usr/share/sddm/themes/silent
    sudo cp -rf "$SCRIPT_DIR/sddm/themes/silent/"* /usr/share/sddm/themes/silent/

    # Install RedHat fonts for SDDM
    if [ -d "$SCRIPT_DIR/sddm/themes/silent/fonts" ]; then
        sudo cp -r "$SCRIPT_DIR/sddm/themes/silent/fonts/"{redhat,redhat-vf} /usr/share/fonts/ 2>/dev/null || true
        sudo fc-cache -f >/dev/null 2>&1 || true
    fi

    # Configure /etc/sddm.conf
    if [ -f "$SCRIPT_DIR/sddm/sddm.conf" ]; then
        [ -f /etc/sddm.conf ] && sudo cp -f /etc/sddm.conf /etc/sddm.conf.hydra_bkp
        sudo cp -f "$SCRIPT_DIR/sddm/sddm.conf" /etc/sddm.conf
    fi

    # Disable conflicting display managers
    DMS=("gdm" "lightdm" "lxdm" "ly")
    for dm in "${DMS[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            echo "  -> Disabling conflicting Display Manager: $dm"
            sudo systemctl disable "$dm.service" 2>/dev/null || true
        fi
    done

    # Enable SDDM
    sudo systemctl enable sddm.service -f >/dev/null 2>&1 || true
    echo -e "  -> ${C_GREEN}[ OK ] Silent SDDM installed and enabled with animated theme!${RESET}"
fi

# ==============================================================================
# Phase 6: System Services & State
# ==============================================================================
echo -e "\n${C_CYAN}[ INFO ]${RESET} Enabling core system services..."
sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
sudo systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true

# Write Hydra Linux version stamp
mkdir -p "$(dirname "$VERSION_FILE")"
cat <<EOF > "$VERSION_FILE"
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WALLPAPER_DIR="${WALLPAPER_DIR}"
EOF

# ==============================================================================
# Phase 7: Completion
# ==============================================================================
draw_header
echo -e "${C_GREEN}${BOLD}✓ Installation Complete!${RESET}\n"
echo -e "Hydra Linux has been successfully deployed to your system."
echo -e "  • ${BOLD}Compositor:${RESET}    Hyprland with Lua engine (~/.config/hypr/hyprland.lua)"
echo -e "  • ${BOLD}Desktop Shell:${RESET} Quickshell widgets with dynamic Matugen theming"
echo -e "  • ${BOLD}Greeter:${RESET}       Silent SDDM with animated video wallpapers"
echo -e "  • ${BOLD}Backups:${RESET}       $BACKUP_DIR\n"
echo -e "${C_YELLOW}Note: It is recommended to log out or restart your system for all changes to take effect.${RESET}\n"
