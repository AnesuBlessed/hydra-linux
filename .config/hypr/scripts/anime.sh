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

# Run an fzf menu inside kitty to choose Sub or Dub
CHOICE=$(printf "1. Subbed\n2. Dubbed" | fzf --prompt="📺 Select Anime Version: " --pointer="▶" --border=rounded --margin=2 --height=40%)

if [[ "$CHOICE" == *"Dubbed"* ]]; then
    exec "$ANICLI_BIN" --dub "$@"
elif [[ "$CHOICE" == *"Subbed"* ]]; then
    exec "$ANICLI_BIN" "$@"
fi
