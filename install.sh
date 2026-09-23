#!/usr/bin/env bash
#
# Hydra Linux installer — Hyprland · Quickshell · Matugen · Silent SDDM
# Dependency-free: pure Bash UI, no gum, no external TUI toolkit.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HYDRA_VERSION="$(cat "$SCRIPT_DIR/version.txt" 2>/dev/null || echo "unknown")"
STATE_FILE="$HOME/.local/state/hydra-linux-version"
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
LOG_FILE="$(mktemp -t hydra-install.XXXXXXXX.log)"
CONFIGS=(hypr quickshell kitty cava matugen rofi swayosd fastfetch)

# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════
COLOR=auto
TTY_IN=false
if [[ -r /dev/tty && -t 1 ]]; then TTY_IN=true; fi

ui_init() {
    if [[ "$COLOR" == never ]] || { [[ "$COLOR" == auto ]] && { [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; }; }; then
        C_RESET='' C_BOLD='' C_DIM='' C_MAGENTA='' C_VIOLET='' C_CYAN=''
        C_GREEN='' C_AMBER='' C_RED='' C_GREY=''
        SYM_OK="[ok]" SYM_ERR="[!!]" SYM_DOT="*" SYM_ARROW="->"
    else
        C_RESET=$'\e[0m'   C_BOLD=$'\e[1m'      C_DIM=$'\e[2m'
        C_MAGENTA=$'\e[38;5;177m' C_VIOLET=$'\e[38;5;141m' C_CYAN=$'\e[38;5;80m'
        C_GREEN=$'\e[38;5;78m'    C_AMBER=$'\e[38;5;215m'  C_RED=$'\e[38;5;203m'
        C_GREY=$'\e[38;5;245m'
        SYM_OK="✓" SYM_ERR="✗" SYM_DOT="•" SYM_ARROW="→"
    fi
    COLS=$( { tput cols; } 2>/dev/null || echo 80 )
    if [[ ! "$COLS" =~ ^[0-9]+$ ]] || (( COLS < 40 )); then COLS=80; fi
    if (( COLS > 80 )); then COLS=80; fi
    return 0
}

rule() {
    local line="" i
    for (( i = 0; i < COLS; i++ )); do line+="─"; done
    printf '%s%s%s\n' "$C_GREY" "$line" "$C_RESET"
}

banner() {
    local gradient=("$C_MAGENTA" "$C_MAGENTA" "$C_VIOLET" "$C_VIOLET" "$C_CYAN" "$C_CYAN")
    local art=(
'██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗ '
'██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗'
'███████║ ╚████╔╝ ██║  ██║██████╔╝███████║'
'██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║'
'██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║'
'╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
    )
    printf '\n'
    if [[ "$COLS" -ge 46 && -n "$C_RESET" ]]; then
        local i
        for i in "${!art[@]}"; do printf '  %s%s%s\n' "${gradient[i]}" "${art[i]}" "$C_RESET"; done
    else
        printf '  %s%sHYDRA LINUX%s\n' "$C_BOLD" "$C_VIOLET" "$C_RESET"
    fi
    printf '\n  %sHyprland %s Quickshell %s Matugen %s Silent SDDM%s\n' \
        "$C_GREY" "$SYM_DOT" "$SYM_DOT" "$SYM_DOT" "$C_RESET"
    printf '  %sv%s%s   %sCtrl+C aborts at any time%s\n\n' \
        "$C_CYAN" "$HYDRA_VERSION" "$C_RESET" "$C_DIM" "$C_RESET"
}

STEP_N=0
step()    { STEP_N=$((STEP_N + 1)); printf '\n%s%s[%d/%d]%s %s%s%s\n' "$C_BOLD" "$C_VIOLET" "$STEP_N" "$STEP_TOTAL" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
ok()      { printf '  %s%s%s %s\n' "$C_GREEN" "$SYM_OK" "$C_RESET" "$1"; }
warn()    { printf '  %s!%s %s\n' "$C_AMBER" "$C_RESET" "$1"; }
fail()    { printf '  %s%s%s %s\n' "$C_RED" "$SYM_ERR" "$C_RESET" "$1" >&2; }
info()    { printf '  %s%s%s\n' "$C_GREY" "$1" "$C_RESET"; }
die()     { fail "$1"; printf '\n  %sInstall log: %s%s\n\n' "$C_GREY" "$LOG_FILE" "$C_RESET" >&2; exit 1; }

SUDO_PID=""
hide_cursor() { [[ -t 1 ]] && printf '\e[?25l'; return 0; }
show_cursor() { [[ -t 1 ]] && printf '\e[?25h'; return 0; }

# run <label> <command...> — spinner while the command runs, output to the log.
run() {
    local label="$1"; shift
    if [[ ! -t 1 ]]; then
        printf '  %s %s\n' "$SYM_ARROW" "$label"
        if "$@" >>"$LOG_FILE" 2>&1; then ok "$label"; return 0; fi
        return 1
    fi

    "$@" >>"$LOG_FILE" 2>&1 &
    local job=$!
    local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 start=$SECONDS
    hide_cursor
    while kill -0 "$job" 2>/dev/null; do
        printf '\r\e[2K  %s%s%s %s %s(%ds)%s' \
            "$C_CYAN" "${frames[i++ % 10]}" "$C_RESET" "$label" "$C_DIM" "$((SECONDS - start))" "$C_RESET"
        sleep 0.08
    done
    show_cursor
    printf '\r\e[2K'
    if wait "$job"; then ok "$label"; return 0; fi
    fail "$label"
    return 1
}

progress() { # progress <done> <total> <label>
    [[ -t 1 ]] || return 0
    local done=$1 total=$2 label=$3 width=28 bar="" i
    local filled=$(( total > 0 ? done * width / total : 0 ))
    for (( i = 0; i < filled; i++ )); do bar+="━"; done
    printf '\r\e[2K  %s%s%s%*s %s%d/%d%s %s' \
        "$C_VIOLET" "$bar" "$C_RESET" "$((width - filled))" '' \
        "$C_GREY" "$done" "$total" "$C_RESET" "${label:0:24}"
}

confirm() { # confirm <prompt> <default y|n>
    local prompt="$1" default="${2:-n}" ans hint="[y/N]"
    [[ "$default" == y ]] && hint="[Y/n]" || true
    if [[ "$TTY_IN" != true ]]; then [[ "$default" == y ]]; return; fi
    printf '  %s %s%s%s ' "$prompt" "$C_DIM" "$hint" "$C_RESET"
    read -r ans </dev/tty || ans=""
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy] ]]
}

# Multi-select menu. Reads MENU_LABELS + MENU_STATE (1/0), writes back MENU_STATE.
menu() {
    local n=${#MENU_LABELS[@]} cur=0 key rest i

    if [[ "$TTY_IN" != true ]]; then
        info "Non-interactive terminal — using recommended defaults."
        return 0
    fi

    printf '  %sSelect components%s  %s↑↓ move   space toggle   enter confirm%s\n\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
    hide_cursor
    while :; do
        for i in "${!MENU_LABELS[@]}"; do
            local mark="  " pointer="  " color="$C_RESET"
            [[ "${MENU_STATE[i]}" == 1 ]] && mark="${C_GREEN}${SYM_OK}${C_RESET} " || true
            [[ $i -eq $cur ]] && { pointer="${C_VIOLET}${SYM_ARROW}${C_RESET} "; color="$C_BOLD"; } || true
            printf '\e[2K  %s%s%s%s%s\n' "$pointer" "$mark" "$color" "${MENU_LABELS[i]}" "$C_RESET"
        done
        IFS= read -rsn1 key </dev/tty || key=""
        if [[ "$key" == $'\e' ]]; then
            IFS= read -rsn2 -t 0.05 rest </dev/tty || rest=""
            key+="$rest"
        fi
        case "$key" in
            $'\e[A'|k) cur=$(( (cur - 1 + n) % n )) ;;
            $'\e[B'|j) cur=$(( (cur + 1) % n )) ;;
            ' ')       MENU_STATE[cur]=$(( 1 - MENU_STATE[cur] )) ;;
            ''|$'\n')  break ;;
            q)         show_cursor; die "Aborted." ;;
        esac
        printf '\e[%dA' "$n"
    done
    show_cursor
    printf '\n'
}

cleanup() {
    local code=$?
    [[ -n "$SUDO_PID" ]] && kill "$SUDO_PID" 2>/dev/null || true
    show_cursor
    if (( code != 0 && code != 1 )); then
        printf '\n  %sInterrupted. Log: %s%s\n' "$C_GREY" "$LOG_FILE" "$C_RESET"
    fi
    return 0
}
trap cleanup EXIT
trap 'die "Interrupted by user."' INT TERM

# ══════════════════════════════════════════════════════════════════════════════
# ARGUMENTS
# ══════════════════════════════════════════════════════════════════════════════
UNATTENDED=false
SKIP_PKGS=false
INSTALL_SDDM=true
INSTALL_WALLPAPERS=true
INSTALL_NVIM=false
INSTALL_ZSH=false
INSTALL_NVIDIA=""

usage() {
    cat <<EOF
Hydra Linux installer

Usage: ./install.sh [options]

  -y, --yes            Non-interactive install with recommended defaults
      --skip-pkgs      Deploy configurations only, skip package installation
      --no-sddm        Skip the Silent SDDM greeter
      --no-wallpapers  Skip the bundled wallpaper collection
      --with-nvim      Include Neovim with the Lua language server
      --with-zsh       Include the Zsh shell
      --nvidia         Force NVIDIA proprietary driver installation
      --no-nvidia      Never install NVIDIA proprietary drivers
      --no-color       Disable colored output (also honours NO_COLOR)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--unattended) UNATTENDED=true ;;
        --skip-pkgs)           SKIP_PKGS=true ;;
        --no-sddm)             INSTALL_SDDM=false ;;
        --no-wallpapers)       INSTALL_WALLPAPERS=false ;;
        --with-nvim)           INSTALL_NVIM=true ;;
        --with-zsh)            INSTALL_ZSH=true ;;
        --nvidia)              INSTALL_NVIDIA=true ;;
        --no-nvidia)           INSTALL_NVIDIA=false ;;
        --no-color)            COLOR=never ;;
        -h|--help)             COLOR=never; ui_init; usage; exit 0 ;;
        *)                     COLOR=never; ui_init; usage >&2; echo; echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

ui_init
[[ -t 1 ]] && clear || true
banner

# ══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT
# ══════════════════════════════════════════════════════════════════════════════
[[ ${BASH_VERSINFO[0]} -ge 4 ]] || die "Bash 4 or newer is required."
[[ $EUID -ne 0 ]] || die "Do not run this installer as root — it installs into \$HOME and calls sudo itself."
[[ -f /etc/os-release ]] || die "Cannot detect the distribution (/etc/os-release is missing)."

# shellcheck disable=SC1091
DETECTED_OS="$(. /etc/os-release && echo "${ID:-unknown}")"
# shellcheck disable=SC1091
OS_PRETTY="$(. /etc/os-release && echo "${PRETTY_NAME:-$DETECTED_OS}")"
# shellcheck disable=SC1091
OS_LIKE="$(. /etc/os-release && echo "${ID_LIKE:-}")"

case "$DETECTED_OS $OS_LIKE" in
    *arch*|*cachyos*|*endeavouros*|*garuda*|*manjaro*) ;;
    *) die "Unsupported distribution '$DETECTED_OS' — Hydra Linux targets Arch and Arch-based systems." ;;
esac
command -v pacman &>/dev/null || die "pacman not found — this installer requires an Arch-based system."

GPU_VENDOR="Unknown"
GPU_RAW="$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)"
case "${GPU_RAW,,}" in
    *nvidia*)                        GPU_VENDOR="NVIDIA" ;;
    *amd*|*"advanced micro devices"*) GPU_VENDOR="AMD" ;;
    *intel*)                         GPU_VENDOR="Intel" ;;
esac

printf '  %sSystem%s  %s\n' "$C_GREY" "$C_RESET" "$OS_PRETTY"
printf '  %sGPU%s     %s\n' "$C_GREY" "$C_RESET" "$GPU_VENDOR"
printf '  %sLog%s     %s\n\n' "$C_GREY" "$C_RESET" "$LOG_FILE"
rule

# ══════════════════════════════════════════════════════════════════════════════
# COMPONENT SELECTION
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$UNATTENDED" == false ]]; then
    printf '\n'
    MENU_LABELS=(
        "Silent SDDM greeter with animated backgrounds"
        "Bundled wallpaper collection"
        "Neovim with Lua language server"
        "Zsh shell"
        "Skip package installation (deploy configs only)"
    )
    MENU_STATE=(
        "$([[ "$INSTALL_SDDM" == true ]] && echo 1 || echo 0)"
        "$([[ "$INSTALL_WALLPAPERS" == true ]] && echo 1 || echo 0)"
        "$([[ "$INSTALL_NVIM" == true ]] && echo 1 || echo 0)"
        "$([[ "$INSTALL_ZSH" == true ]] && echo 1 || echo 0)"
        "$([[ "$SKIP_PKGS" == true ]] && echo 1 || echo 0)"
    )
    menu
    [[ "${MENU_STATE[0]}" == 1 ]] && INSTALL_SDDM=true       || INSTALL_SDDM=false
    [[ "${MENU_STATE[1]}" == 1 ]] && INSTALL_WALLPAPERS=true || INSTALL_WALLPAPERS=false
    [[ "${MENU_STATE[2]}" == 1 ]] && INSTALL_NVIM=true       || INSTALL_NVIM=false
    [[ "${MENU_STATE[3]}" == 1 ]] && INSTALL_ZSH=true        || INSTALL_ZSH=false
    [[ "${MENU_STATE[4]}" == 1 ]] && SKIP_PKGS=true          || SKIP_PKGS=false

    if [[ "$GPU_VENDOR" == "NVIDIA" && -z "$INSTALL_NVIDIA" ]]; then
        confirm "Install NVIDIA proprietary drivers?" n && INSTALL_NVIDIA=true || INSTALL_NVIDIA=false
    fi
fi
[[ -z "$INSTALL_NVIDIA" ]] && INSTALL_NVIDIA=false

STEP_TOTAL=3
[[ "$SKIP_PKGS" == false ]] && STEP_TOTAL=$((STEP_TOTAL + 1)) || true
[[ "$INSTALL_SDDM" == true ]] && STEP_TOTAL=$((STEP_TOTAL + 1)) || true

# Keep sudo warm so long package builds never stall on a password prompt.
if [[ "$SKIP_PKGS" == false || "$INSTALL_SDDM" == true ]]; then
    printf '\n'
    info "Administrator privileges are required for packages and the greeter."
    sudo -v || die "sudo authentication failed."
    ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    SUDO_PID=$!
fi

# ══════════════════════════════════════════════════════════════════════════════
# PACKAGES
# ══════════════════════════════════════════════════════════════════════════════
PKGS=(
    hyprland hypridle hyprpolkitagent
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    quickshell-git matugen-bin swayosd-git rofi kitty cava fastfetch
    sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-imageformats
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack
    libpulse pamixer playerctl pavucontrol alsa-utils easyeffects lsp-plugins
    firefox dolphin
    grim slurp satty awww mpvpaper gpu-screen-recorder nwg-displays zenity
    wl-clipboard cliphist jq yq socat inotify-tools brightnessctl
    acpi iw lm_sensors bc imagemagick wget file git
    psmisc unzip fd ripgrep power-profiles-daemon
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd
    qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects
    qt6-wayland qt5ct qt6ct adw-gtk-theme
    qt6-5compat qt6-websockets python-websockets
)
[[ "$INSTALL_NVIM" == true ]]   && PKGS+=(neovim lua-language-server nodejs npm python) || true
[[ "$INSTALL_ZSH" == true ]]    && PKGS+=(zsh) || true
[[ "$INSTALL_NVIDIA" == true ]] && PKGS+=(nvidia-dkms nvidia-utils lib32-nvidia-utils linux-headers egl-wayland) || true

if [[ "$SKIP_PKGS" == false ]]; then
    step "Installing packages"

    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        # shellcheck disable=SC2016  # expansions are intentionally evaluated by the inner shell
        run "Installing AUR helper (yay)" bash -c '
            set -e
            sudo pacman -S --noconfirm --needed base-devel git
            build="$(mktemp -d)"
            trap "rm -rf \"$build\"" EXIT
            git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build"
            cd "$build" && makepkg -si --noconfirm
        ' || die "Could not install an AUR helper — see the log for details."
    fi

    if   command -v yay  &>/dev/null; then INSTALL_CMD=(yay -S --noconfirm --needed)
    elif command -v paru &>/dev/null; then INSTALL_CMD=(paru -S --noconfirm --needed)
    else                                   INSTALL_CMD=(sudo pacman -S --noconfirm --needed)
    fi

    MISSING=()
    for pkg in "${PKGS[@]}"; do
        pacman -Q "$pkg" &>/dev/null || MISSING+=("$pkg")
    done

    if [[ ${#MISSING[@]} -eq 0 ]]; then
        ok "All ${#PKGS[@]} packages are already installed."
    else
        JOBS=$(( $(nproc) / 2 )); (( JOBS < 1 )) && JOBS=1; (( JOBS > 4 )) && JOBS=4
        export MAKEFLAGS="-j$JOBS" CARGO_BUILD_JOBS="$JOBS"

        if ! run "Installing ${#MISSING[@]} packages (this can take a while)" \
                 "${INSTALL_CMD[@]}" "${MISSING[@]}"; then
            # A single bad package should not abort the batch: retry one by one.
            warn "Batch install failed — retrying packages individually."
            FAILED=()
            for i in "${!MISSING[@]}"; do
                progress "$i" "${#MISSING[@]}" "${MISSING[i]}"
                "${INSTALL_CMD[@]}" "${MISSING[i]}" >>"$LOG_FILE" 2>&1 || FAILED+=("${MISSING[i]}")
            done
            progress "${#MISSING[@]}" "${#MISSING[@]}" "done"
            printf '\r\e[2K'
            if [[ ${#FAILED[@]} -gt 0 ]]; then
                warn "${#FAILED[@]} package(s) failed: ${FAILED[*]}"
                info "Continuing — see $LOG_FILE, then install them manually."
            else
                ok "Packages installed."
            fi
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# BACKUP
# ══════════════════════════════════════════════════════════════════════════════
step "Backing up existing configuration"
BACKUP_DIR="$HOME/.config/hydra_backup/backup_$(date +%Y%m%d_%H%M%S)"
BACKED_UP=0
mkdir -p "$BACKUP_DIR"
for cfg in "${CONFIGS[@]}"; do
    [[ -e "$HOME/.config/$cfg" ]] || continue
    cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/" \
        || die "Could not back up ~/.config/$cfg — refusing to overwrite it."
    BACKED_UP=$((BACKED_UP + 1))
done
if [[ $BACKED_UP -eq 0 ]]; then
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    BACKUP_DIR="(nothing to back up)"
    ok "No existing configuration found."
else
    ok "$BACKED_UP config(s) saved to $BACKUP_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════════
# DEPLOY
# ══════════════════════════════════════════════════════════════════════════════
step "Deploying Hydra Linux"

deploy_configs() {
    mkdir -p "$HOME/.config" "$HOME/.local/bin"
    for cfg in "${CONFIGS[@]}"; do
        [[ -d "$SCRIPT_DIR/.config/$cfg" ]] || continue
        rm -rf "${HOME:?}/.config/$cfg"
        cp -a "$SCRIPT_DIR/.config/$cfg" "$HOME/.config/"
    done
    if [[ -f "$SCRIPT_DIR/assets/default_avatar.png" && ! -f "$HOME/.face.icon" ]]; then
        install -Dm644 "$SCRIPT_DIR/assets/default_avatar.png" "$HOME/.face.icon"
        install -Dm644 "$SCRIPT_DIR/assets/default_avatar.png" "$HOME/.face"
    fi
    if [[ -f "$SCRIPT_DIR/utils/bin/cava" ]]; then
        install -Dm755 "$SCRIPT_DIR/utils/bin/cava" "$HOME/.local/bin/cava"
    fi
    if [[ -d "$HOME/.config/hypr/scripts" ]]; then
        find "$HOME/.config/hypr/scripts" -type f -name '*.sh' -exec chmod +x {} +
    fi
    return 0
}
run "Deploying configuration files" deploy_configs || die "Configuration deployment failed."

if [[ -f "$HOME/.config/hypr/scripts/settings_watcher.sh" ]]; then
    run "Compiling engine templates" bash "$HOME/.config/hypr/scripts/settings_watcher.sh" --compile || true
fi
run "Updating font cache" fc-cache -f || true

if [[ "$INSTALL_WALLPAPERS" == true && -d "$SCRIPT_DIR/wallpapers" ]]; then
    mkdir -p "$WALLPAPER_DIR"
    # shellcheck disable=SC2016  # $1/$2 are positional parameters of the inner shell
    run "Deploying bundled wallpapers" \
        bash -c 'cp -rn "$1/wallpapers/." "$2/" 2>/dev/null || true' _ "$SCRIPT_DIR" "$WALLPAPER_DIR" || true
fi

# ══════════════════════════════════════════════════════════════════════════════
# SILENT SDDM
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$INSTALL_SDDM" == true && -d "$SCRIPT_DIR/sddm/themes/silent" ]]; then
    step "Configuring the Silent SDDM greeter"

    install_sddm() {
        sudo mkdir -p /usr/share/sddm/themes/silent /usr/share/sddm/faces
        sudo cp -rf "$SCRIPT_DIR/sddm/themes/silent/." /usr/share/sddm/themes/silent/

        if [[ -d "$SCRIPT_DIR/sddm/themes/silent/fonts" ]]; then
            sudo cp -rf "$SCRIPT_DIR/sddm/themes/silent/fonts/." /usr/share/fonts/ 2>/dev/null || true
            sudo fc-cache -f >/dev/null 2>&1 || true
        fi

        if [[ -f "$SCRIPT_DIR/sddm/sddm.conf" ]]; then
            [[ -f /etc/sddm.conf ]] && sudo cp -a /etc/sddm.conf "/etc/sddm.conf.hydra.bak" || true
            sudo install -Dm644 "$SCRIPT_DIR/sddm/sddm.conf" /etc/sddm.conf
        fi

        # Matugen syncs the greeter accent colors from the user session, so the
        # theme configs must stay writable — group-owned by the user, not 0666.
        if compgen -G "/usr/share/sddm/themes/silent/configs/*.conf" >/dev/null; then
            sudo chown "root:$(id -gn)" /usr/share/sddm/themes/silent/configs/*.conf
            sudo chmod 664 /usr/share/sddm/themes/silent/configs/*.conf
        fi

        if [[ -f "$HOME/.face.icon" ]]; then
            sudo install -Dm644 -o "$(id -un)" -g "$(id -gn)" \
                "$HOME/.face.icon" "/usr/share/sddm/faces/$(id -un).face.icon"
        fi
    }
    run "Installing the Silent theme" install_sddm || die "Silent SDDM installation failed."

    enable_sddm() {
        local dm
        for dm in gdm lightdm lxdm ly; do
            if systemctl is-enabled "$dm.service" &>/dev/null; then
                sudo systemctl disable "$dm.service" || true
            fi
        done
        sudo systemctl enable -f sddm.service
    }
    run "Enabling sddm.service" enable_sddm || warn "Could not enable sddm.service — enable it manually."
fi

# ══════════════════════════════════════════════════════════════════════════════
# SERVICES & STATE
# ══════════════════════════════════════════════════════════════════════════════
step "Enabling system services"
for svc in NetworkManager power-profiles-daemon; do
    if systemctl list-unit-files "$svc.service" &>/dev/null; then
        # shellcheck disable=SC2024  # the log file belongs to the invoking user, not root
        sudo systemctl enable "$svc.service" >>"$LOG_FILE" 2>&1 || warn "Could not enable $svc.service"
    fi
done
ok "NetworkManager and power-profiles-daemon enabled."

mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" <<EOF
LOCAL_VERSION="${HYDRA_VERSION}"
INSTALL_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
WALLPAPER_DIR="${WALLPAPER_DIR}"
EOF

# ══════════════════════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════════════════════
printf '\n'
rule
printf '\n  %s%sHydra Linux %s is installed.%s\n\n' "$C_BOLD" "$C_GREEN" "$HYDRA_VERSION" "$C_RESET"
printf '  %sCompositor%s  Hyprland\n' "$C_GREY" "$C_RESET"
printf '  %sShell%s       Quickshell + Matugen dynamic theming\n' "$C_GREY" "$C_RESET"
[[ "$INSTALL_SDDM" == true ]] && printf '  %sGreeter%s     Silent SDDM\n' "$C_GREY" "$C_RESET" || true
printf '  %sBackups%s     %s\n' "$C_GREY" "$C_RESET" "$BACKUP_DIR"
printf '  %sLog%s         %s\n' "$C_GREY" "$C_RESET" "$LOG_FILE"
printf '\n  %s%s Log out or reboot to start Hyprland.%s\n\n' "$C_AMBER" "$SYM_ARROW" "$C_RESET"
