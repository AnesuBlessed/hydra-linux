#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="$(cat "$SCRIPT_DIR/version.txt" 2>/dev/null || echo "1.0.1")"
VERSION_FILE="$HOME/.local/state/hydra-linux-version"

# ─── Colors & Formatting ─────────────────────────────────────────────────────
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_PURPLE="\e[38;2;180;120;255m"
C_BLUE="\e[38;2;120;170;255m"
C_CYAN="\e[38;2;100;220;255m"
C_GREEN="\e[38;2;120;230;140m"
C_YELLOW="\e[38;2;250;200;100m"
C_RED="\e[38;2;255;110;110m"
C_MUTED="\e[38;2;130;130;150m"

# Ensure cursor is restored on exit or interruption
trap 'printf "\e[?25h"' EXIT
trap 'printf "\e[?25h\n\n${C_RED}Installation aborted by user.${C_RESET}\n"; exit 130' INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# 1. ARGUMENT PARSING
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
        -v|--version)
            echo "Hydra Linux Installer v${HYDRA_VERSION}"
            exit 0 ;;
        -h|--help)
            echo -e "${C_BOLD}Hydra Linux Installer v${HYDRA_VERSION}${C_RESET}"
            echo ""
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  -y, --yes, --unattended  Non-interactive mode with recommended defaults"
            echo "  --skip-pkgs              Deploy configurations only, skip package manager"
            echo "  --no-sddm                Skip Silent SDDM login greeter setup"
            echo "  --with-nvim              Include Neovim with Lua IDE language server"
            echo "  --with-zsh               Include Zsh shell"
            echo "  -v, --version            Display version information"
            echo "  -h, --help               Display this help message"
            echo ""
            exit 0 ;;
        *)
            echo -e "${C_RED}Unknown option: $1${C_RESET}"
            exit 1 ;;
    esac
done

WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"

# ─────────────────────────────────────────────────────────────────────────────
# 2. DISTRO DETECTION
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -f /etc/os-release ]; then
    echo -e "${C_RED}Error: Cannot detect OS — /etc/os-release not found.${C_RESET}"
    exit 1
fi
DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
OS_PRETTY=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

case "$DETECTED_OS" in
    arch|cachyos|endeavouros|garuda|manjaro|parch) ;;
    *)
        echo -e "${C_RED}Unsupported distribution: '$DETECTED_OS'${C_RESET}"
        echo -e "${C_YELLOW}Hydra Linux targets Arch Linux and Arch-based distributions.${C_RESET}"
        exit 1 ;;
esac

# ─── GPU Detection ────────────────────────────────────────────────────────────
GPU_VENDOR="Unknown"
GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
if echo "$GPU_RAW" | grep -qi "nvidia"; then GPU_VENDOR="NVIDIA"
elif echo "$GPU_RAW" | grep -qi "amd\|advanced micro devices"; then GPU_VENDOR="AMD"
elif echo "$GPU_RAW" | grep -qi "intel"; then GPU_VENDOR="Intel"
fi

# ─── Privilege Escalation ────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${C_MUTED}:: Requesting administrator privileges...${C_RESET}"
    sudo -v || { echo -e "${C_RED}Administrator privileges required to continue.${C_RESET}"; exit 1; }
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# ─── UI Helper Functions ─────────────────────────────────────────────────────
print_header() {
    echo -e "${C_PURPLE}${C_BOLD}"
    cat << 'ART'
    __  __            __               __    _                  
   / / / /__  ______/ /________ _    / /   (_)___  __  ___  __  
  / /_/ / _ \/ __  / ___/ __ `/     / /   / / __ \/ / / /\ \/ / 
 / __  /  __/ /_/ / /  / /_/ /     / /___/ / / / / /_/ /  >  <  
/_/ /_/\___/\__,_/_/   \__,_/     /_____/_/_/ /_/\__,_/  /_/\_\ 
ART
    echo -e "${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}HYDRA LINUX${C_RESET} ${C_MUTED}•${C_RESET} Unified Hyprland & Quickshell Rice ${C_MUTED}(v${HYDRA_VERSION})${C_RESET}"
    echo -e "  ${C_MUTED}Press Ctrl+C at any time to abort installation.${C_RESET}\n"
}

print_sysinfo() {
    echo -e "  ${C_PURPLE}╭─ System Environment ───────────────────────────────────────────${C_RESET}"
    echo -e "  ${C_PURPLE}│${C_RESET}  ${C_BOLD}Distribution${C_RESET} : ${C_CYAN}${OS_PRETTY}${C_RESET}"
    echo -e "  ${C_PURPLE}│${C_RESET}  ${C_BOLD}GPU Vendor${C_RESET}   : ${C_BLUE}${GPU_VENDOR}${C_RESET}"
    echo -e "  ${C_PURPLE}│${C_RESET}  ${C_BOLD}Target User${C_RESET}  : ${C_GREEN}${USER}${C_RESET}"
    echo -e "  ${C_PURPLE}╰────────────────────────────────────────────────────────────────${C_RESET}\n"
}

print_phase() {
    echo -e "\n  ${C_PURPLE}${C_BOLD}:: [Phase $1] $2${C_RESET}"
}

print_success() {
    echo -e "  ${C_GREEN}${C_BOLD}✓${C_RESET} $1"
}

print_error() {
    echo -e "  ${C_RED}${C_BOLD}✗${C_RESET} $1"
}

print_info() {
    echo -e "  ${C_YELLOW}${C_BOLD}ℹ${C_RESET} $1"
}

do_spin() {
    local title="$1"; shift

    if [ ! -t 1 ]; then
        echo -e "  :: $title"
        "$@"
        return $?
    fi

    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local pid

    printf "\e[?25l"
    "$@" &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C_PURPLE}%s${C_RESET}  %s\e[K" "${spin[i]}" "$title"
        i=$(( (i + 1) % ${#spin[@]} ))
        sleep 0.07
    done

    wait "$pid"
    local exit_code=$?
    printf "\e[?25h"

    if [ $exit_code -eq 0 ]; then
        printf "\r  ${C_GREEN}${C_BOLD}✓${C_RESET}  %s\e[K\n" "$title"
        return 0
    else
        printf "\r  ${C_RED}${C_BOLD}✗${C_RESET}  %s\e[K\n" "$title"
        return $exit_code
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. INTERACTIVE COMPONENT SELECTION
# ─────────────────────────────────────────────────────────────────────────────
DRIVER_PKGS=()

if [ "$UNATTENDED" = false ] && [ -t 0 ]; then
    clear
    print_header
    print_sysinfo

    opts=(
        "Silent SDDM Greeter & Animated Wallpapers"
        "Bundled Wallpapers Collection"
        "Neovim with Lua IDE Support"
        "Zsh Shell"
        "Skip Package Installation (deploy configs only)"
    )
    states=(1 1 0 0 0)

    render_menu() {
        echo -e "  ${C_PURPLE}╭─ Component Selection ──────────────────────────────────────────${C_RESET}"
        echo -e "  ${C_PURPLE}│${C_RESET}"
        echo -e "  ${C_PURPLE}│${C_RESET}  ${C_MUTED}Enter a number ${C_BOLD}[1-5]${C_RESET}${C_MUTED} to toggle, or press ${C_BOLD}[Enter]${C_RESET}${C_MUTED} to proceed:${C_RESET}"
        echo -e "  ${C_PURPLE}│${C_RESET}"
        for i in "${!opts[@]}"; do
            local num=$((i + 1))
            if [ "${states[i]}" -eq 1 ]; then
                printf "  ${C_PURPLE}│${C_RESET}  ${C_BOLD}[%d]${C_RESET} [${C_GREEN}✔${C_RESET}] ${C_BOLD}%s${C_RESET}\n" "$num" "${opts[i]}"
            else
                printf "  ${C_PURPLE}│${C_RESET}  ${C_MUTED}[%d] [ ] %s${C_RESET}\n" "$num" "${opts[i]}"
            fi
        done
        echo -e "  ${C_PURPLE}│${C_RESET}"
        echo -e "  ${C_PURPLE}╰────────────────────────────────────────────────────────────────${C_RESET}"
    }

    while true; do
        render_menu
        read -rp "  Toggle option [1-5] or press Enter to continue: " choice
        if [[ -z "$choice" ]]; then
            break
        elif [[ "$choice" =~ ^[1-5]$ ]]; then
            idx=$((choice - 1))
            if [ "${states[idx]}" -eq 1 ]; then states[idx]=0; else states[idx]=1; fi
            clear
            print_header
            print_sysinfo
        else
            clear
            print_header
            print_sysinfo
        fi
    done

    [ "${states[0]}" -eq 1 ] && INSTALL_SDDM=true || INSTALL_SDDM=false
    [ "${states[1]}" -eq 1 ] && INSTALL_WALLPAPERS=true || INSTALL_WALLPAPERS=false
    [ "${states[2]}" -eq 1 ] && INSTALL_NVIM=true || INSTALL_NVIM=false
    [ "${states[3]}" -eq 1 ] && INSTALL_ZSH=true || INSTALL_ZSH=false
    [ "${states[4]}" -eq 1 ] && SKIP_PKGS=true || SKIP_PKGS=false

    echo ""
    if [ "$GPU_VENDOR" == "NVIDIA" ]; then
        echo -e "  ${C_YELLOW}:: NVIDIA Graphics Card Detected${C_RESET}"
        read -rp "  Install NVIDIA proprietary drivers & modesetting? [y/N]: " ans_gpu
        if [[ "$ans_gpu" =~ ^[Yy]$ ]]; then
            DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")
        fi
    fi
else
    print_header
    print_sysinfo
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. PACKAGE LISTS & TOOLING
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
    "psmisc" "unzip" "fd" "ripgrep" "power-profiles-daemon" "fzf" "mpv" "ani-cli" "ani-skip-git"
    "ttf-jetbrains-mono-nerd" "ttf-iosevka-nerd"
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects"
    "qt6-wayland" "qt5ct" "qt6ct" "adw-gtk-theme"
    "qt6-5compat" "qt6-websockets" "python-websockets"
)

[[ "$INSTALL_NVIM" = true ]] && CORE_PKGS+=("neovim" "lua-language-server" "nodejs" "npm" "python3")
[[ "$INSTALL_ZSH"  = true ]] && CORE_PKGS+=("zsh")

bootstrap_core_deps() {
    sudo pacman -S --noconfirm --needed jq curl >/dev/null 2>&1
}

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    do_spin "Bootstrapping core dependencies (jq, curl)..." bootstrap_core_deps
fi

install_aur_helper() {
    sudo pacman -S --noconfirm --needed base-devel git >/dev/null 2>&1 &&     rm -rf /tmp/yay-bin &&     git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin >/dev/null 2>&1 &&     (cd /tmp/yay-bin && makepkg -si --noconfirm >/dev/null 2>&1) &&     rm -rf /tmp/yay-bin
}

if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    do_spin "Installing AUR helper (yay)..." install_aur_helper
fi

if   command -v yay  &>/dev/null; then PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &>/dev/null; then PKG_MANAGER="paru -S --noconfirm --needed"
else                                   PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1: PACKAGES
# ─────────────────────────────────────────────────────────────────────────────
check_missing_packages() {
    rm -f /tmp/hydra_missing_pkgs
    for pkg in "${ALL_PKGS[@]}"; do
        [[ -z "$pkg" ]] && continue
        if ! pacman -Q "$pkg" &>/dev/null; then
            echo "$pkg" >> /tmp/hydra_missing_pkgs
        fi
    done
}

install_single_pkg() {
    local pkg="$1"
    yes 'Y' | env CARGO_BUILD_JOBS="$SAFE_JOBS" MAKEFLAGS="-j$SAFE_JOBS" $PKG_MANAGER "$pkg" >/tmp/hydra_pkg.log 2>&1
}

if [ "$SKIP_PKGS" = false ]; then
    print_phase "1/5" "Installing System & Rice Packages"
    ALL_PKGS=("${CORE_PKGS[@]}" "${DRIVER_PKGS[@]}")
    MISSING_PKGS=()

    do_spin "Analyzing required packages against system database..." check_missing_packages

    if [ -f /tmp/hydra_missing_pkgs ]; then
        readarray -t MISSING_PKGS < /tmp/hydra_missing_pkgs
        rm -f /tmp/hydra_missing_pkgs
    fi

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        print_success "All required packages are already installed."
    else
        print_info "Found ${#MISSING_PKGS[@]} missing packages to install."
        SAFE_JOBS=$(( $(nproc) / 2 ))
        [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
        [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4

        count=0
        total=${#MISSING_PKGS[@]}
        for pkg in "${MISSING_PKGS[@]}"; do
            ((count++))
            if ! do_spin "[$count/$total] Installing $pkg..." install_single_pkg "$pkg"; then
                print_error "Failed to install $pkg — check /tmp/hydra_pkg.log"
            fi
        done
        print_success "Package installation phase completed."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2: BACKUP
# ─────────────────────────────────────────────────────────────────────────────
print_phase "2/5" "Backing Up Existing Configurations"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/hydra_backup/backup_${BACKUP_DATE}"

backup_configs() {
    mkdir -p "$BACKUP_DIR"
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d "$HOME/.config/$cfg" ] || [ -f "$HOME/.config/$cfg" ]; then
            cp -rf "$HOME/.config/$cfg" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
}

do_spin "Creating safety backup in $BACKUP_DIR..." backup_configs
print_success "Existing configurations safely archived."

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3: DEPLOYMENT
# ─────────────────────────────────────────────────────────────────────────────
print_phase "3/5" "Deploying Hydra Linux Configurations"

deploy_configs() {
    mkdir -p "$HOME/.config" "$HOME/.local/bin"
    for cfg in hypr quickshell kitty cava matugen rofi swayosd fastfetch; do
        if [ -d "$SCRIPT_DIR/.config/$cfg" ]; then
            rm -rf "$HOME/.config/$cfg"
            cp -r "$SCRIPT_DIR/.config/$cfg" "$HOME/.config/"
        fi
    done

    if [ -f "$SCRIPT_DIR/assets/default_avatar.png" ] && [ ! -f "$HOME/.face.icon" ]; then
        cp -f "$SCRIPT_DIR/assets/default_avatar.png" "$HOME/.face.icon"
        cp -f "$SCRIPT_DIR/assets/default_avatar.png" "$HOME/.face"
        chmod 644 "$HOME/.face.icon" "$HOME/.face"
    fi
    if [ -f "$SCRIPT_DIR/utils/bin/cava" ]; then
        cp -f "$SCRIPT_DIR/utils/bin/cava" "$HOME/.local/bin/cava"
        chmod +x "$HOME/.local/bin/cava"
    fi
    if [ -f "$SCRIPT_DIR/utils/bin/ani-cli" ]; then
        cp -f "$SCRIPT_DIR/utils/bin/ani-cli" "$HOME/.local/bin/ani-cli"
        chmod +x "$HOME/.local/bin/ani-cli"
    fi
    if [ -d "$HOME/.config/hypr/scripts" ]; then
        find "$HOME/.config/hypr/scripts" -type f -name '*.sh' -exec chmod +x {} +
    fi
}

do_spin "Deploying dotfiles and themes..." deploy_configs
print_success "Configurations and script permissions deployed."

compile_templates() {
    bash "$HOME/.config/hypr/scripts/settings_watcher.sh" --compile >/dev/null 2>&1 || true
}

if [ -f "$HOME/.config/hypr/scripts/settings_watcher.sh" ]; then
    do_spin "Compiling theme engine templates..." compile_templates
fi

update_font_cache() {
    fc-cache -f >/dev/null 2>&1 || true
}
do_spin "Updating system font cache..." update_font_cache

deploy_wallpapers() {
    mkdir -p "$WALLPAPER_DIR"
    if [ -d "$SCRIPT_DIR/wallpapers" ]; then
        cp -rn "$SCRIPT_DIR/wallpapers/"* "$WALLPAPER_DIR/" 2>/dev/null || true
    fi
}

if [ "$INSTALL_WALLPAPERS" = true ]; then
    do_spin "Deploying bundled wallpaper collection..." deploy_wallpapers
    print_success "Wallpapers deployed to $WALLPAPER_DIR."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4: SDDM GREETER
# ─────────────────────────────────────────────────────────────────────────────
setup_sddm() {
    sudo mkdir -p /usr/share/sddm/themes/silent
    sudo cp -rf "$SCRIPT_DIR/sddm/themes/silent/"* /usr/share/sddm/themes/silent/
    if [ -d "$SCRIPT_DIR/sddm/themes/silent/fonts" ]; then
        sudo cp -r "$SCRIPT_DIR/sddm/themes/silent/fonts/"{redhat,redhat-vf} /usr/share/fonts/ 2>/dev/null || true
        sudo fc-cache -f >/dev/null 2>&1 || true
    fi
    if [ -f "$SCRIPT_DIR/sddm/sddm.conf" ]; then
        [ -f /etc/sddm.conf ] && sudo cp -f /etc/sddm.conf /etc/sddm.conf.hydra_bkp
        sudo cp -f "$SCRIPT_DIR/sddm/sddm.conf" /etc/sddm.conf
    fi
    sudo chmod 666 /usr/share/sddm/themes/silent/configs/*.conf 2>/dev/null || true
    sudo mkdir -p /usr/share/sddm/faces
    if [ -f "$HOME/.face.icon" ]; then
        sudo cp -f "$HOME/.face.icon" "/usr/share/sddm/faces/$USER.face.icon"
        sudo chown "$USER:$USER" "/usr/share/sddm/faces/$USER.face.icon" 2>/dev/null || true
        sudo chmod 644 "/usr/share/sddm/faces/$USER.face.icon" 2>/dev/null || true
    fi

    for dm in gdm lightdm lxdm ly; do
        systemctl is-enabled "${dm}.service" &>/dev/null &&             sudo systemctl disable "${dm}.service" 2>/dev/null || true
    done
    sudo systemctl enable sddm.service -f >/dev/null 2>&1 || true
}

if [ "$INSTALL_SDDM" = true ] && [ -d "$SCRIPT_DIR/sddm/themes/silent" ]; then
    print_phase "4/5" "Configuring Silent SDDM Greeter"
    do_spin "Installing Silent SDDM theme & video background engine..." setup_sddm
    print_success "Silent SDDM greeter enabled with video wallpapers."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5: SERVICES & VERSIONING
# ─────────────────────────────────────────────────────────────────────────────
print_phase "5/5" "Enabling Core System Services"

enable_services() {
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
    sudo systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true
}

do_spin "Enabling NetworkManager and power-profiles-daemon..." enable_services
print_success "System background services enabled."

mkdir -p "$(dirname "$VERSION_FILE")"
cat > "$VERSION_FILE" << EOF_VERSION
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WALLPAPER_DIR="${WALLPAPER_DIR}"
EOF_VERSION

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${C_GREEN}${C_BOLD}╭─ INSTALLATION COMPLETE ─────────────────────────────────────────${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  Hydra Linux ${C_BOLD}${HYDRA_VERSION}${C_RESET} has been deployed successfully."
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  • ${C_BOLD}Compositor${C_RESET} : Hyprland"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  • ${C_BOLD}Shell${C_RESET}      : Quickshell + Matugen dynamic theming"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  • ${C_BOLD}Greeter${C_RESET}    : Silent SDDM"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  • ${C_BOLD}Backups${C_RESET}    : $BACKUP_DIR"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}  ${C_YELLOW}${C_BOLD}:: Log out or reboot your system to enter Hydra Linux.${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}│${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}╰─────────────────────────────────────────────────────────────────${C_RESET}\n"
