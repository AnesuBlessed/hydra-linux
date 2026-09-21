#!/usr/bin/env bash
set -e

# --- 0. Bootstrap UI ---
# Check and install 'gum' for a beautiful UI experience
if ! command -v gum &>/dev/null; then
    echo -e "\e[36m[ INFO ]\e[0m Bootstrapping modern installer UI (gum)..."
    sudo pacman -Sy --noconfirm --needed gum >/dev/null 2>&1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="1.0.0"
VERSION_FILE="$HOME/.local/state/hydra-linux-version"

# Clean Screen
clear

# --- Draw Beautiful Header with Gum ---
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 80 --margin "1 2" --padding "1 2" \
	"🐉 HYDRA LINUX" \
	"Unified Hyprland, Quickshell & Silent SDDM Environment" \
	"Version ${HYDRA_VERSION}"

gum style --foreground 240 --italic "Press Ctrl+C at any time to abort installation."

# --- 1. Distro Detection ---
if [ -f /etc/os-release ]; then
    DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
else
    gum style --foreground 196 "Cannot detect OS. /etc/os-release not found."
    exit 1
fi

case "$DETECTED_OS" in
    arch|cachyos|endeavouros|garuda|manjaro|parch) ;;
    *)
        gum style --foreground 196 "Unsupported distribution: '$DETECTED_OS'"
        gum style --foreground 214 "Hydra Linux targets Arch-based systems."
        exit 1
        ;;
esac

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
        *) gum style --foreground 196 "Unknown option: $1"; exit 1 ;;
    esac
done

WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"

# Hardware / GPU detection
GPU_VENDOR="Unknown"
GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
if echo "$GPU_RAW" | grep -qi "nvidia"; then GPU_VENDOR="NVIDIA"
elif echo "$GPU_RAW" | grep -qi "amd\|advanced micro devices"; then GPU_VENDOR="AMD"
elif echo "$GPU_RAW" | grep -qi "intel"; then GPU_VENDOR="Intel"
fi

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    gum spin --spinner dot --title "Bootstrapping core dependencies (jq, curl)..." -- sudo pacman -S --noconfirm --needed jq curl >/dev/null 2>&1
fi

if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    gum spin --spinner dot --title "Installing AUR helper (yay)..." -- bash -c 'sudo pacman -S --noconfirm --needed base-devel git && git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm && rm -rf /tmp/yay-bin' >/dev/null 2>&1
fi

if command -v yay &>/dev/null; then PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &>/dev/null; then PKG_MANAGER="paru -S --noconfirm --needed"
else PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

# Package Lists
CORE_PKGS=(
    "hyprland" "hypridle" "hyprpolkitagent" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "quickshell-git" "matugen-bin" "swayosd-git" "rofi" "kitty" "cava" "fastfetch"
    "sddm" "qt6-svg" "qt6-virtualkeyboard" "qt6-multimedia-ffmpeg" "qt6-imageformats"
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "libpulse" "pamixer" "playerctl" "pavucontrol" "alsa-utils" "easyeffects" "lsp-plugins"
    "firefox" "dolphin" "nautilus" "kitty"
    "grim" "slurp" "satty" "awww" "mpvpaper" "gpu-screen-recorder" "nwg-displays" "zenity"
    "wl-clipboard" "cliphist" "jq" "yq" "socat" "inotify-tools" "brightnessctl" "acpi" "iw" "lm_sensors" "bc" "imagemagick" "wget" "file" "git" "psmisc" "unzip" "fd" "ripgrep" "power-profiles-daemon"
    "ttf-jetbrains-mono-nerd" "ttf-iosevka-nerd"
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland" "qt5ct" "qt6ct" "adw-gtk-theme" "qt6-5compat" "qt6-websockets" "python-websockets"
)

DRIVER_PKGS=()

# Interactive Menu
if [ "$UNATTENDED" = false ]; then
    gum style --foreground 99 "System Detected:" "$(gum style --bold "$OS_PRETTY")"
    gum style --foreground 99 "GPU Detected:" "$(gum style --bold "$GPU_VENDOR")"
    echo ""

    gum style --bold "Select installation components:"
    CHOICES=$(gum choose --no-limit --cursor="🐉 " --selected="Silent SDDM & Animated Wallpapers,Bundled Wallpapers" "Silent SDDM & Animated Wallpapers" "Bundled Wallpapers" "Neovim with Lua Support" "Zsh Shell" "Skip Package Installation")
    
    if echo "$CHOICES" | grep -q "Silent SDDM"; then INSTALL_SDDM=true; else INSTALL_SDDM=false; fi
    if echo "$CHOICES" | grep -q "Bundled Wallpapers"; then INSTALL_WALLPAPERS=true; else INSTALL_WALLPAPERS=false; fi
    if echo "$CHOICES" | grep -q "Neovim"; then INSTALL_NVIM=true; fi
    if echo "$CHOICES" | grep -q "Zsh"; then INSTALL_ZSH=true; fi
    if echo "$CHOICES" | grep -q "Skip Package"; then SKIP_PKGS=true; fi

    if [ "$GPU_VENDOR" == "NVIDIA" ]; then
        if gum confirm "Install NVIDIA proprietary drivers and configure kernel modesetting?"; then
            DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")
        fi
    fi
fi

[[ "$INSTALL_NVIM" = true ]] && CORE_PKGS+=("neovim" "lua-language-server" "nodejs" "npm" "python3")
[[ "$INSTALL_ZSH" = true ]] && CORE_PKGS+=("zsh")

# --- Phase 1: Packages ---
if [ "$SKIP_PKGS" = false ]; then
    gum style --foreground 212 --bold "📦 Installing Packages"
    
    ALL_PKGS=("${CORE_PKGS[@]}" "${DRIVER_PKGS[@]}")
    MISSING_PKGS=()

    gum spin --spinner dot --title "Analyzing required packages..." -- bash -c '
        for pkg in "$@"; do
            [[ -z "$pkg" ]] && continue
            if ! pacman -Q "$pkg" &>/dev/null; then echo "$pkg" >> /tmp/missing_pkgs; fi
        done
    ' _ "${ALL_PKGS[@]}"

    if [ -f /tmp/missing_pkgs ]; then
        readarray -t MISSING_PKGS < /tmp/missing_pkgs
        rm /tmp/missing_pkgs
    fi

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        gum style --foreground 46 "✓ All required packages are already installed."
    else
        gum style --foreground 214 "Found ${#MISSING_PKGS[@]} missing packages."
        SAFE_JOBS=$(( $(nproc) / 2 )); [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1; [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4
        
        for pkg in "${MISSING_PKGS[@]}"; do
            if ! gum spin --spinner meter --title "Installing $pkg..." -- bash -c "yes 'Y' | env CARGO_BUILD_JOBS=$SAFE_JOBS MAKEFLAGS='-j$SAFE_JOBS' $PKG_MANAGER $pkg >/tmp/pkg_install.log 2>&1"; then
                gum style --foreground 196 "✗ Failed to install $pkg (check logs)"
            fi
        done
        gum style --foreground 46 "✓ Package installation complete."
    fi
    echo ""
fi

# --- Phase 2: Configuration Backup ---
gum style --foreground 212 --bold "💾 Backing up existing configurations"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/hydra_backup/backup_${BACKUP_DATE}"

gum spin --spinner dot --title "Creating backups in $BACKUP_DIR..." -- bash -c "
    mkdir -p '$BACKUP_DIR'
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d \"\$HOME/.config/\$cfg\" ] || [ -f \"\$HOME/.config/\$cfg\" ]; then
            cp -rf \"\$HOME/.config/\$cfg\" \"$BACKUP_DIR/\" 2>/dev/null || true
        fi
    done
"
gum style --foreground 46 "✓ Existing configs safely backed up."
echo ""

# --- Phase 3: Deployment ---
gum style --foreground 212 --bold "🚀 Deploying Hydra Linux Environment"

gum spin --spinner dot --title "Deploying configuration files..." -- bash -c "
    mkdir -p '$HOME/.config' '$HOME/.local/bin'
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d \"$SCRIPT_DIR/.config/\$cfg\" ]; then
            rm -rf \"\$HOME/.config/\$cfg\"
            cp -r \"$SCRIPT_DIR/.config/\$cfg\" \"\$HOME/.config/\"
        fi
    done
    
    if [ -f \"$SCRIPT_DIR/assets/default_avatar.png\" ] && [ ! -f \"\$HOME/.face.icon\" ]; then
        cp -f \"$SCRIPT_DIR/assets/default_avatar.png\" \"\$HOME/.face.icon\"
        cp -f \"$SCRIPT_DIR/assets/default_avatar.png\" \"\$HOME/.face\"
        chmod 644 \"\$HOME/.face.icon\" \"\$HOME/.face\"
    fi
    
    if [ -f \"$SCRIPT_DIR/utils/bin/cava\" ]; then
        cp -f \"$SCRIPT_DIR/utils/bin/cava\" \"\$HOME/.local/bin/cava\"
        chmod +x \"\$HOME/.local/bin/cava\"
    fi
    
    if [ -d \"\$HOME/.config/hypr/scripts\" ]; then
        find \"\$HOME/.config/hypr/scripts\" -type f -name '*.sh' -exec chmod +x {} +
    fi
"
gum style --foreground 46 "✓ Core configurations deployed."

# Compile templates
if [ -f "$HOME/.config/hypr/scripts/settings_watcher.sh" ]; then
    gum spin --spinner dot --title "Compiling engine templates..." -- bash "$HOME/.config/hypr/scripts/settings_watcher.sh" --compile >/dev/null 2>&1 || true
fi

gum spin --spinner dot --title "Updating font cache..." -- fc-cache -fv >/dev/null 2>&1 || true

if [ "$INSTALL_WALLPAPERS" = true ]; then
    gum spin --spinner dot --title "Deploying showcase wallpapers..." -- bash -c "
        mkdir -p '$WALLPAPER_DIR'
        if [ -d \"$SCRIPT_DIR/wallpapers\" ]; then
            cp -rn \"$SCRIPT_DIR/wallpapers/\"* \"$WALLPAPER_DIR/\" 2>/dev/null || true
        fi
    "
    gum style --foreground 46 "✓ Wallpapers deployed."
fi
echo ""

# --- Phase 4: SDDM ---
if [ "$INSTALL_SDDM" = true ] && [ -d "$SCRIPT_DIR/sddm/themes/silent" ]; then
    gum style --foreground 212 --bold "🔒 Configuring Silent SDDM Greeter"
    
    gum spin --spinner dot --title "Setting up login manager..." -- bash -c "
        sudo mkdir -p /usr/share/sddm/themes/silent
        sudo cp -rf \"$SCRIPT_DIR/sddm/themes/silent/\"* /usr/share/sddm/themes/silent/
        if [ -d \"$SCRIPT_DIR/sddm/themes/silent/fonts\" ]; then
            sudo cp -r \"$SCRIPT_DIR/sddm/themes/silent/fonts/\"{redhat,redhat-vf} /usr/share/fonts/ 2>/dev/null || true
            sudo fc-cache -f >/dev/null 2>&1 || true
        fi
        if [ -f \"$SCRIPT_DIR/sddm/sddm.conf\" ]; then
            [ -f /etc/sddm.conf ] && sudo cp -f /etc/sddm.conf /etc/sddm.conf.hydra_bkp
            sudo cp -f \"$SCRIPT_DIR/sddm/sddm.conf\" /etc/sddm.conf
        fi
        sudo chmod 666 /usr/share/sddm/themes/silent/configs/*.conf 2>/dev/null || true
        sudo mkdir -p /usr/share/sddm/faces
        if [ -f \"\$HOME/.face.icon\" ]; then sudo cp -f \"\$HOME/.face.icon\" \"/usr/share/sddm/faces/\$USER.face.icon\"; fi
        sudo chown \"\$USER:\$USER\" \"/usr/share/sddm/faces/\$USER.face.icon\" 2>/dev/null || true
        sudo chmod 644 \"/usr/share/sddm/faces/\$USER.face.icon\" 2>/dev/null || true
    "
    
    # Disable conflicting display managers
    DMS=("gdm" "lightdm" "lxdm" "ly")
    for dm in "${DMS[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            sudo systemctl disable "$dm.service" 2>/dev/null || true
        fi
    done
    
    sudo systemctl enable sddm.service -f >/dev/null 2>&1 || true
    gum style --foreground 46 "✓ SDDM enabled with animated video backgrounds."
    echo ""
fi

# --- Phase 5: Services ---
sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
sudo systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true

mkdir -p "$(dirname "$VERSION_FILE")"
cat <<EOF > "$VERSION_FILE"
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WALLPAPER_DIR="${WALLPAPER_DIR}"
