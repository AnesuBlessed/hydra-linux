#!/usr/bin/env bash
# Hydra Linux Anime Launcher
# Launches ani-cli in a dedicated floating Kitty window

ANICLI_BIN="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"

if [ ! -x "$ANICLI_BIN" ]; then
    if command -v notify-send &>/dev/null; then
        notify-send "Hydra Anime" "ani-cli not found. Fetching standalone script..." -i video-player
    fi
    mkdir -p "$HOME/.local/bin"
    curl -sL https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli -o "$HOME/.local/bin/ani-cli"
    chmod +x "$HOME/.local/bin/ani-cli"
    ANICLI_BIN="$HOME/.local/bin/ani-cli"
fi

exec kitty --class hydra-anime --title "Hydra Anime" "$ANICLI_BIN" "$@"
