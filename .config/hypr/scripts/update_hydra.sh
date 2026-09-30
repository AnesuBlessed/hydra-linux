#!/usr/bin/env bash
# ==============================================================================
# update_hydra.sh - Pull latest Hydra Linux repository changes and apply updates
# ==============================================================================
set -e

echo -e "\033[1;35m=== Hydra Linux System Updater ===\033[0m\n"

REPO_DIR=""
POSSIBLE_DIRS=(
    "$HOME/Projects/Hydra Linux"
    "$HOME/Projects/hydra-linux"
    "$HOME/.local/share/hydra-linux"
    "$HOME/hydra-linux"
)

for dir in "${POSSIBLE_DIRS[@]}"; do
    if [ -d "$dir/.git" ]; then
        REPO_DIR="$dir"
        break
    fi
done

if [ -z "$REPO_DIR" ]; then
    echo -e "\033[1;34m[*] Cloning Hydra Linux to ~/.local/share/hydra-linux...\033[0m"
    mkdir -p "$HOME/.local/share"
    git clone https://github.com/AnesuBlessed/hydra-linux.git "$HOME/.local/share/hydra-linux"
    REPO_DIR="$HOME/.local/share/hydra-linux"
fi

echo -e "\033[1;34m[*] Updating repository in $REPO_DIR...\033[0m"
cd "$REPO_DIR"
git fetch origin main
git checkout main
git pull --rebase origin main

echo -e "\n\033[1;34m[*] Running Hydra Linux installer...\033[0m"
bash ./install.sh --skip-pkgs --no-sddm -y

echo -e "\n\033[1;34m[*] Reloading desktop environment...\033[0m"
bash "$HOME/.config/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true

echo -e "\n\033[1;32m[✓] Hydra Linux update complete!\033[0m"
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Hydra Linux" "Update Complete" "Hydra Linux has been updated and reloaded successfully!"
fi
