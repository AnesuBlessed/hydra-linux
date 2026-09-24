#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ◈ Hydra Anime Launcher
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Opens a themed kitty window running the anime menu.

ANICLI_BIN="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"

# Auto-fetch ani-cli if missing
if [ ! -x "$ANICLI_BIN" ]; then
    command -v notify-send &>/dev/null && \
        notify-send "Hydra Anime" "ani-cli not found. Fetching..." -i video-player
    mkdir -p "$HOME/.local/bin"
    curl -sL https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli \
        -o "$HOME/.local/bin/ani-cli"
    chmod +x "$HOME/.local/bin/ani-cli"
fi

ANIME_CONF="$HOME/.config/kitty/hydra-anime.conf"

# Generate themed kitty config on first run
if [ ! -f "$ANIME_CONF" ]; then
    mkdir -p "$HOME/.config/kitty"
    cat > "$ANIME_CONF" << 'KITTYCONF'
font_family      JetBrains Mono
font_size        9.0
background_opacity 0.92
background       #0d0d1a
foreground       #e0d6ff
cursor           #c792ea
cursor_text_color #0d0d1a
selection_foreground #0d0d1a
selection_background #c792ea
color0  #1a1a2e
color1  #ff6b6b
color2  #82ffb5
color3  #ffd93d
color4  #6c9bff
color5  #c792ea
color6  #89ddff
color7  #e0d6ff
color8  #3a3a5c
color9  #ff8a8a
color10 #a3ffd0
color11 #ffe680
color12 #8cb4ff
color13 #dbb0f5
color14 #a8e8ff
color15 #ffffff
window_padding_width 8
hide_window_decorations yes
confirm_os_window_close 0
enable_audio_bell no
KITTYCONF
fi

exec kitty --class hydra-anime --title "Hydra Anime" \
    --config "$HOME/.config/kitty/kitty.conf" \
    --config "$ANIME_CONF" \
    bash "$HOME/.config/hypr/scripts/anime_inner.sh"
