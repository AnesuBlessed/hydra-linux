#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="$(cat "$SCRIPT_DIR/version.txt" 2>/dev/null || echo "1.0.1")"
VERSION_FILE="$HOME/.local/state/hydra-linux-version"

clear

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_header() {
    echo -e "\e[38;2;180;120;255m\e[1m╔══════════════════════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[38;2;180;120;255m\e[1m║                             HYDRA LINUX                              ║\e[0m"
    echo -e "\e[38;2;180;120;255m\e[1m║        Unified Hyprland, Quickshell & Silent SDDM Environment        ║\e[0m"
    echo -e "\e[38;2;180;120;255m\e[1m║                           Version ${HYDRA_VERSION}                              ║\e[0m"
    echo -e "\e[38;2;180;120;255m\e[1m╚══════════════════════════════════════════════════════════════════════╝\e[0m"
    echo -e "  \e[90mPress Ctrl+C at any time to abort installation.\e[0m\n"
}

print_step() {
    echo -e "\n\e[38;2;180;120;255m\e[1m:: $1\e[0m"
}
print_success() {
    echo -e "  \e[32m\e[1m✓\e[0m $1"
}
print_error() {
    echo -e "  \e[31m\e[1m✗\e[0m $1"
}
print_info() {
    echo -e "  \e[33m\e[1mℹ\e[0m $1"
}
do_spin() {
    local title="$1"; shift
    echo -e "  \e[36m\e[1m->\e[0m $title"
    bash -c "$*"
}
ask_confirm() {
    local prompt="$1"
    local ans
    read -rp "  $prompt [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

print_header

# ─────────────────────────────────────────────────────────────────────────────
# 1. DISTRO DETECTION
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -f /etc/os-release ]; then
    print_error "Cannot detect OS — /etc/os-release not found."
    exit 1
fi
DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

case "$DETECTED_OS" in
    arch|cachyos|endeavouros|garuda|manjaro|parch) ;;
    *)
        print_error "Unsupported distribution: '$DETECTED_OS'"
        print_info "Hydra Linux targets Arch Linux and Arch-based distributions."
        exit 1 ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# 2. ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────────────────
UNATTENDED=false
SKIP_PKGS=false
INSTALL_SDDM=true
INSTALL_NVIM=false
INSTALL_ZSH=false
INSTALL_WALLPAPERS=true

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -y|--yes|--unattended) UNATTENDED=true; shift ;;
        --skip-pkgs)           SKIP_PKGS=true; shift ;;
        --no-sddm)             INSTALL_SDDM=false; shift ;;
        --with-nvim)           INSTALL_NVIM=true; shift ;;
        --with-zsh)            INSTALL_ZSH=true; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "  -y, --yes        Non-interactive (recommended defaults)"
            echo "  --skip-pkgs      Deploy configs only, skip package install"
            echo "  --no-sddm        Skip Silent SDDM greeter setup"
            echo "  --with-nvim      Include Neovim with Lua language server"
            echo "  --with-zsh       Include Zsh shell"
            echo "  -h, --help       Show this help"
            exit 0 ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac
done

WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"

# ─── GPU Detection ────────────────────────────────────────────────────────────
GPU_VENDOR="Unknown"
GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
if echo "$GPU_RAW" | grep -qi "nvidia"; then GPU_VENDOR="NVIDIA"
elif echo "$GPU_RAW" | grep -qi "amd\|advanced micro devices"; then GPU_VENDOR="AMD"
elif echo "$GPU_RAW" | grep -qi "intel"; then GPU_VENDOR="Intel"
fi

# ─── Bootstrap core deps ──────────────────────────────────────────────────────
if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    do_spin "Bootstrapping core dependencies (jq, curl)..." \
        "sudo pacman -S --noconfirm --needed jq curl >/dev/null 2>&1"
fi

# ─── AUR helper ───────────────────────────────────────────────────────────────
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    do_spin "Installing AUR helper (yay)..." \
        "sudo pacman -S --noconfirm --needed base-devel git && \
         git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
         cd /tmp/yay-bin && makepkg -si --noconfirm && rm -rf /tmp/yay-bin"
fi

if   command -v yay  &>/dev/null; then PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &>/dev/null; then PKG_MANAGER="paru -S --noconfirm --needed"
else                                   PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. PACKAGE LIST
# ─────────────────────────────────────────────────────────────────────────────
CORE_PKGS=(
    "hyprland" "hypridle" "hyprpolkitagent"
    "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "quickshell-git" "matugen-bin" "swayosd-git" "rofi" "kitty" "cava" "fastfetch"
    "sddm" "qt6-svg" "qt6-virtualkeyboard" "qt6-multimedia-ffmpeg" "qt6-imageformats"
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack"
    "libpulse" "pamixer" "playerctl" "pavucontrol" "alsa-utils" "easyeffects" "lsp-plugins"
    "firefox" "dolphin"
    "grim" "slurp" "satty" "awww" "mpvpaper" "gpu-screen-recorder" "nwg-displays" "zenity"
    "wl-clipboard" "cliphist" "jq" "yq" "socat" "inotify-tools" "brightnessctl"
    "acpi" "iw" "lm_sensors" "bc" "imagemagick" "wget" "file" "git"
    "psmisc" "unzip" "fd" "ripgrep" "power-profiles-daemon"
    "ttf-jetbrains-mono-nerd" "ttf-iosevka-nerd"
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects"
    "qt6-wayland" "qt5ct" "qt6ct" "adw-gtk-theme"
    "qt6-5compat" "qt6-websockets" "python-websockets"
)
DRIVER_PKGS=()

# ─────────────────────────────────────────────────────────────────────────────
# 4. INTERACTIVE MENU
# ─────────────────────────────────────────────────────────────────────────────
if [ "$UNATTENDED" = false ]; then
    echo -e "  \e[1mSystem:\e[0m \e[36m$OS_PRETTY\e[0m"
    echo -e "  \e[1mGPU:   \e[0m \e[36m$GPU_VENDOR\e[0m"
    echo ""
    echo -e "  \e[90mConfigure your installation components:\e[0m"
    echo -e "  \e[90mPress Enter to accept the default option (shown in CAPS).\e[0m"
    echo ""

    read -rp "  Install Silent SDDM Greeter & Animated Wallpapers? [Y/n]: " ans_sddm
    [[ "$ans_sddm" =~ ^[Nn]$ ]] && INSTALL_SDDM=false

    read -rp "  Install bundled wallpapers collection?             [Y/n]: " ans_wp
    [[ "$ans_wp" =~ ^[Nn]$ ]] && INSTALL_WALLPAPERS=false

    read -rp "  Install Neovim with Lua IDE support?               [y/N]: " ans_nvim
    [[ "$ans_nvim" =~ ^[Yy]$ ]] && INSTALL_NVIM=true

    read -rp "  Install Zsh shell?                                 [y/N]: " ans_zsh
    [[ "$ans_zsh" =~ ^[Yy]$ ]] && INSTALL_ZSH=true

    read -rp "  Skip package installation (deploy configs only)?   [y/N]: " ans_skip
    [[ "$ans_skip" =~ ^[Yy]$ ]] && SKIP_PKGS=true

    if [ "$GPU_VENDOR" == "NVIDIA" ]; then
        read -rp "  Install NVIDIA proprietary drivers & modesetting?  [y/N]: " ans_gpu
        [[ "$ans_gpu" =~ ^[Yy]$ ]] && DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")
    fi
fi

[[ "$INSTALL_NVIM" = true ]] && CORE_PKGS+=("neovim" "lua-language-server" "nodejs" "npm" "python3")
[[ "$INSTALL_ZSH"  = true ]] && CORE_PKGS+=("zsh")

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1: PACKAGES
# ─────────────────────────────────────────────────────────────────────────────
if [ "$SKIP_PKGS" = false ]; then
    print_step "Phase 1: Installing Packages"
    ALL_PKGS=("${CORE_PKGS[@]}" "${DRIVER_PKGS[@]}")
    MISSING_PKGS=()

    do_spin "Analyzing required packages..." "
        for pkg in ${ALL_PKGS[*]}; do
            [[ -z \"\$pkg\" ]] && continue
            if ! pacman -Q \"\$pkg\" &>/dev/null; then echo \"\$pkg\" >> /tmp/hydra_missing_pkgs; fi
        done
    "

    if [ -f /tmp/hydra_missing_pkgs ]; then
        readarray -t MISSING_PKGS < /tmp/hydra_missing_pkgs
        rm /tmp/hydra_missing_pkgs
    fi

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        print_success "All required packages are already installed."
    else
        print_info "Found ${#MISSING_PKGS[@]} missing packages."
        SAFE_JOBS=$(( $(nproc) / 2 ))
        [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
        [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4

        for pkg in "${MISSING_PKGS[@]}"; do
            if ! do_spin "Installing $pkg..." \
                "yes 'Y' | env CARGO_BUILD_JOBS=$SAFE_JOBS MAKEFLAGS='-j$SAFE_JOBS' $PKG_MANAGER $pkg >/tmp/hydra_pkg.log 2>&1"; then
                print_error "Failed to install $pkg — check /tmp/hydra_pkg.log"
            fi
        done
        print_success "Package installation complete."
    fi
    echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2: BACKUP
# ─────────────────────────────────────────────────────────────────────────────
print_step "Phase 2: Backing Up Existing Configurations"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/hydra_backup/backup_${BACKUP_DATE}"

do_spin "Creating backup in $BACKUP_DIR..." "
    mkdir -p '$BACKUP_DIR'
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d \"\$HOME/.config/\$cfg\" ] || [ -f \"\$HOME/.config/\$cfg\" ]; then
            cp -rf \"\$HOME/.config/\$cfg\" \"$BACKUP_DIR/\" 2>/dev/null || true
        fi
    done
"
print_success "Existing configs safely backed up to $BACKUP_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3: DEPLOYMENT
# ─────────────────────────────────────────────────────────────────────────────
print_step "Phase 3: Deploying Hydra Linux"

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
    do_spin "Compiling engine templates..." \
        "bash \"$HOME/.config/hypr/scripts/settings_watcher.sh\" --compile >/dev/null 2>&1 || true"
fi
do_spin "Updating font cache..." "fc-cache -fv >/dev/null 2>&1 || true"

if [ "$INSTALL_WALLPAPERS" = true ]; then
    do_spin "Deploying bundled wallpapers..." "
        mkdir -p '$WALLPAPER_DIR'
        if [ -d \"$SCRIPT_DIR/wallpapers\" ]; then
            cp -rn \"$SCRIPT_DIR/wallpapers/\"* \"$WALLPAPER_DIR/\" 2>/dev/null || true
        fi
    "
    print_success "Wallpapers deployed to $WALLPAPER_DIR"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4: SDDM
# ─────────────────────────────────────────────────────────────────────────────
if [ "$INSTALL_SDDM" = true ] && [ -d "$SCRIPT_DIR/sddm/themes/silent" ]; then
    print_step "Phase 4: Configuring Silent SDDM Greeter"

    do_spin "Installing Silent SDDM theme..." "
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
        if [ -f \"\$HOME/.face.icon\" ]; then
            sudo cp -f \"\$HOME/.face.icon\" \"/usr/share/sddm/faces/\$USER.face.icon\"
            sudo chown \"\$USER:\$USER\" \"/usr/share/sddm/faces/\$USER.face.icon\" 2>/dev/null || true
            sudo chmod 644 \"/usr/share/sddm/faces/\$USER.face.icon\" 2>/dev/null || true
        fi
    "

    for dm in gdm lightdm lxdm ly; do
        systemctl is-enabled "${dm}.service" &>/dev/null && \
            sudo systemctl disable "${dm}.service" 2>/dev/null || true
    done
    sudo systemctl enable sddm.service -f >/dev/null 2>&1 || true
    print_success "SDDM enabled with animated video backgrounds."
    echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5: SERVICES & VERSION
# ─────────────────────────────────────────────────────────────────────────────
print_step "Phase 5: Enabling Core Services"
do_spin "Enabling system services..." "
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
    sudo systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true
"
print_success "NetworkManager and power-profiles-daemon enabled."

mkdir -p "$(dirname "$VERSION_FILE")"
cat > "$VERSION_FILE" << EOF
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WALLPAPER_DIR="${WALLPAPER_DIR}"
EOF

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "\e[32m\e[1m╔══════════════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[32m\e[1m║                        INSTALLATION COMPLETE!                        ║\e[0m"
echo -e "\e[32m\e[1m╚══════════════════════════════════════════════════════════════════════╝\e[0m\n"
echo -e "  Hydra Linux \e[1m${HYDRA_VERSION}\e[0m has been deployed successfully."
echo -e "  • \e[1mCompositor:\e[0m  Hyprland"
echo -e "  • \e[1mShell:\e[0m       Quickshell + Matugen dynamic theming"
echo -e "  • \e[1mGreeter:\e[0m     Silent SDDM"
echo -e "  • \e[1mBackups:\e[0m     $BACKUP_DIR\n"
echo -e "  \e[33m\e[1m:: Log out or reboot to start Hyprland.\e[0m\n"
