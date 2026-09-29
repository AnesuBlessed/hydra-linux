#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hydra Anime - Simple Menu
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export ANI_CLI_DOWNLOAD_DIR="$HOME/Videos/Anime"
mkdir -p "$ANI_CLI_DOWNLOAD_DIR"

clear
echo -e "\033[38;2;199;146;234m\033[1m  ◈ HYDRA ANIME\033[0m\n"

# Use fzf for a clean, simple menu
ACTION=$(printf "Stream (Sub)\nStream (Dub)\nDownload (Sub)\nDownload (Dub)\nQuit" | fzf \
    --prompt="  Action ▸ " \
    --pointer="▶" \
    --border=none \
    --margin=0,2 \
    --height=10 \
    --color="border:#c792ea,prompt:#89ddff,pointer:#82ffb5")

[[ -z "$ACTION" || "$ACTION" == *"Quit"* ]] && exit 0

DUB=""
DL=""

[[ "$ACTION" == *"Dub"* ]] && DUB="--dub"
[[ "$ACTION" == *"Download"* ]] && DL="-d"

echo -e "\n\033[38;2;108;155;255m  Enter search query: \033[0m\c"
read -r QUERY
[[ -z "$QUERY" ]] && exit 0

clear
ANICLI="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"
"$ANICLI" $DL $DUB "$QUERY"

echo -e "\n\033[2m  Press any key to exit...\033[0m"
read -rsn1
