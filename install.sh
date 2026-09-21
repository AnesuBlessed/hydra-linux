#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="1.0.0"
VERSION_FILE="$HOME/.local/state/hydra-linux-version"

# --- 0. Bootstrap UI ---
USE_GUM=false
if ! command -v gum &>/dev/null; then
    echo -e "\e[36m::\e[0m Bootstrapping modern installer UI (gum)..."
    sudo pacman -Sy --noconfirm --needed gum >/dev/null 2>&1 || true
fi

if command -v gum &>/dev/null; then
    USE_GUM=true
fi

# Clean Screen
clear

# --- Helpers ---
print_step() {
    if [ "$USE_GUM" = true ]; then gum style --foreground 212 --bold ":: $1"
    else echo -e "\n\e[35m\e[1m:: $1\e[0m"; fi
}
print_success() {
    if [ "$USE_GUM" = true ]; then gum style --foreground 46 "✓ $1"
    else echo -e "\e[32m✓ $1\e[0m"; fi
}
print_error() {
    if [ "$USE_GUM" = true ]; then gum style --foreground 196 "✗ $1"
    else echo -e "\e[31m✗ $1\e[0m"; fi
}
do_spin() {
    local title="$1"
    shift
    if [ "$USE_GUM" = true ]; then
        gum spin --spinner dot --title "$title" -- bash -c "$*"
    else
        echo -e "\e[36m ->\e[0m $title"
        bash -c "$*"
    fi
}

# --- Header ---
if [ "$USE_GUM" = true ]; then
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 80 --margin "1 2" --padding "1 2" \
        "HYDRA LINUX" \
        "Unified Hyprland, Quickshell & Silent SDDM Environment" \
        "Version ${HYDRA_VERSION}"
    gum style --foreground 240 --italic "Press Ctrl+C at any time to abort installation."
else
    echo -e "\e[35m\e[1m======================================================================\e[0m"
    echo -e "\e[35m\e[1m                           HYDRA LINUX                                \e[0m"
    echo -e "\e[35m\e[1m======================================================================\e[0m"
    echo -e "Version ${HYDRA_VERSION}\n"
    echo -e "Press Ctrl+C at any time to abort installation.\n"
fi

# --- 1. Distro Detection ---
if [ -f /etc/os-release ]; then
    DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
else
    print_error "Cannot detect OS. /etc/os-release not found."
    exit 1
fi

case "$DETECTED_OS" in
    arch|cachyos|endeavouros|garuda|manjaro|parch) ;;
    *)
        print_error "Unsupported distribution: '$DETECTED_OS'"
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
        *) print_error "Unknown option: $1"; exit 1 ;;
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

do_spin "Bootstrapping core dependencies (jq, curl)..." "sudo pacman -S --noconfirm --needed jq curl >/dev/null 2>&1"

if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    do_spin "Installing AUR helper (yay)..." "sudo pacman -S --noconfirm --needed base-devel git && git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm && rm -rf /tmp/yay-bin >/dev/null 2>&1"
fi

if command -v yay &>/dev/null; then PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &>/dev/null; then PKG_MANAGER="paru -S --noconfirm --needed"
else PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

CORE_PKGS=(
    "hyprland" "hypridle" "hyprpolkitagent" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "quickshell-git" "matugen-bin" "swayosd-git" "rofi" "kitty" "cava" "fastfetch"
    "sddm" "qt6-svg" "qt6-virtualkeyboard" "qt6-multimedia-ffmpeg" "qt6-imageformats"
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "libpulse" "pamixer" "playerctl" "pavucontrol" "alsa-utils" "easyeffects" "lsp-plugins"
    "firefox" "dolphin" "nautilus"
    "grim" "slurp" "satty" "awww" "mpvpaper" "gpu-screen-recorder" "nwg-displays" "zenity"
    "wl-clipboard" "cliphist" "jq" "yq" "socat" "inotify-tools" "brightnessctl" "acpi" "iw" "lm_sensors" "bc" "imagemagick" "wget" "file" "git" "psmisc" "unzip" "fd" "ripgrep" "power-profiles-daemon"
    "ttf-jetbrains-mono-nerd" "ttf-iosevka-nerd"
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland" "qt5ct" "qt6ct" "adw-gtk-theme" "qt6-5compat" "qt6-websockets" "python-websockets"
)
DRIVER_PKGS=()

# Interactive Menu
if [ "$UNATTENDED" = false ]; then
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 99 "System Detected: $(gum style --bold "$OS_PRETTY")"
        gum style --foreground 99 "GPU Detected:    $(gum style --bold "$GPU_VENDOR")"
        echo ""
        gum style --bold "Select installation components (Space to toggle, Enter to confirm):"
        CHOICES=$(gum choose --no-limit --cursor="> " --selected="Silent SDDM & Animated Wallpapers,Bundled Wallpapers" "Silent SDDM & Animated Wallpapers" "Bundled Wallpapers" "Neovim with Lua Support" "Zsh Shell" "Skip Package Installation")
        
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
    else
        echo -e "\e[1mSystem Detected:\e[0m $OS_PRETTY"
        echo -e "\e[1mGPU Detected:\e[0m    $GPU_VENDOR\n"
        
        read -p "Install Silent SDDM Greeter & Animated Wallpapers? [Y/n]: " ans_sddm
        [[ "$ans_sddm" =~ ^[Nn]$ ]] && INSTALL_SDDM=false

        read -p "Install bundled wallpapers? [Y/n]: " ans_wp
        [[ "$ans_wp" =~ ^[Nn]$ ]] && INSTALL_WALLPAPERS=false

        read -p "Install Neovim with Lua support? [y/N]: " ans_nvim
        [[ "$ans_nvim" =~ ^[Yy]$ ]] && INSTALL_NVIM=true

        read -p "Install Zsh? [y/N]: " ans_zsh
        [[ "$ans_zsh" =~ ^[Yy]$ ]] && INSTALL_ZSH=true

        read -p "Skip Package Installation (Deploy Configs Only)? [y/N]: " ans_skip
        [[ "$ans_skip" =~ ^[Yy]$ ]] && SKIP_PKGS=true

        if [ "$GPU_VENDOR" == "NVIDIA" ]; then
            read -p "Install NVIDIA proprietary drivers? [y/N]: " ans_gpu
            [[ "$ans_gpu" =~ ^[Yy]$ ]] && DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")
        fi
    fi
fi

[[ "$INSTALL_NVIM" = true ]] && CORE_PKGS+=("neovim" "lua-language-server" "nodejs" "npm" "python3")
[[ "$INSTALL_ZSH" = true ]] && CORE_PKGS+=("zsh")

# --- Phase 1: Packages ---
if [ "$SKIP_PKGS" = false ]; then
    print_step "Phase 1: Installing Packages"
    ALL_PKGS=("${CORE_PKGS[@]}" "${DRIVER_PKGS[@]}")
    MISSING_PKGS=()

    do_spin "Analyzing required packages..." "
        for pkg in ${ALL_PKGS[*]}; do
            if ! pacman -Q \"\$pkg\" &>/dev/null; then echo \"\$pkg\" >> /tmp/missing_pkgs; fi
        done
    "
    if [ -f /tmp/missing_pkgs ]; then
        readarray -t MISSING_PKGS < /tmp/missing_pkgs
        rm /tmp/missing_pkgs
    fi

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        print_success "All required packages are already installed."
    else
        echo -e "Found ${#MISSING_PKGS[@]} missing packages."
        SAFE_JOBS=$(( $(nproc) / 2 )); [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1; [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4
        
        for pkg in "${MISSING_PKGS[@]}"; do
            if ! do_spin "Installing $pkg..." "yes 'Y' | env CARGO_BUILD_JOBS=$SAFE_JOBS MAKEFLAGS='-j$SAFE_JOBS' $PKG_MANAGER $pkg >/tmp/pkg_install.log 2>&1"; then
                print_error "Failed to install $pkg (check /tmp/pkg_install.log)"
            fi
        done
        print_success "Package installation complete."
    fi
    echo ""
fi

# --- Phase 2: Configuration Backup ---
print_step "Phase 2: Backing up existing configurations"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/hydra_backup/backup_${BACKUP_DATE}"

do_spin "Creating backups in $BACKUP_DIR..." "
    mkdir -p '$BACKUP_DIR'
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d \"\$HOME/.config/\$cfg\" ] || [ -f \"\$HOME/.config/\$cfg\" ]; then
            cp -rf \"\$HOME/.config/\$cfg\" \"$BACKUP_DIR/\" 2>/dev/null || true
        fi
    done
"
print_success "Existing configs safely backed up."
echo ""

# --- Phase 3: Deployment ---
print_step "Phase 3: Deploying Hydra Linux Environment"

do_spin "Deploying configuration files..." "
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
print_success "Core configurations deployed."

if [ -f "$HOME/.config/hypr/scripts/settings_watcher.sh" ]; then
    do_spin "Compiling engine templates..." "bash \"$HOME/.config/hypr/scripts/settings_watcher.sh\" --compile >/dev/null 2>&1 || true"
fi
do_spin "Updating font cache..." "fc-cache -fv >/dev/null 2>&1 || true"

if [ "$INSTALL_WALLPAPERS" = true ]; then
    do_spin "Deploying showcase wallpapers..." "
        mkdir -p '$WALLPAPER_DIR'
        if [ -d \"$SCRIPT_DIR/wallpapers\" ]; then cp -rn \"$SCRIPT_DIR/wallpapers/\"* \"$WALLPAPER_DIR/\" 2>/dev/null || true; fi
    "
    print_success "Wallpapers deployed."
fi
echo ""

# --- Phase 4: SDDM ---
if [ "$INSTALL_SDDM" = true ] && [ -d "$SCRIPT_DIR/sddm/themes/silent" ]; then
    print_step "Phase 4: Configuring Silent SDDM Greeter"
    
    do_spin "Setting up login manager..." "
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
    
    DMS=("gdm" "lightdm" "lxdm" "ly")
    for dm in "${DMS[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            sudo systemctl disable "$dm.service" 2>/dev/null || true
        fi
    done
    sudo systemctl enable sddm.service -f >/dev/null 2>&1 || true
    print_success "SDDM enabled with animated video backgrounds."
    echo ""
fi

# --- Phase 5: Services ---
do_spin "Enabling core system services..." "
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
    sudo systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true
"

mkdir -p "$(dirname "$VERSION_FILE")"
cat <<EOF2 > "$VERSION_FILE"
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WALLPAPER_DIR="${WALLPAPER_DIR}"
EOF2

# --- Final Completion ---
if [ "$USE_GUM" = true ]; then
    gum style \
        --foreground 46 --border-foreground 46 --border rounded \
        --align left --width 80 --margin "1 2" --padding "1 2" \
        "INSTALLATION COMPLETE!" "" "Hydra Linux has been successfully deployed to your system." \
        " - Compositor: Hyprland with Lua engine" " - Shell: Quickshell widgets with dynamic Matugen theming" " - Backups: $BACKUP_DIR"
    gum format "# It is highly recommended to log out or restart your system now."
else
    echo -e "\e[32m\e[1mINSTALLATION COMPLETE!\e[0m\n"
    echo -e "Hydra Linux has been successfully deployed to your system."
    echo -e " - Compositor: Hyprland with Lua engine"
    echo -e " - Shell: Quickshell widgets with dynamic Matugen theming"
    echo -e " - Backups: $BACKUP_DIR\n"
    echo -e "\e[33mIt is highly recommended to log out or restart your system now.\e[0m"
fi
echo ""
