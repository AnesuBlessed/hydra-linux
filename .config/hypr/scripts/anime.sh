#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ◈ Hydra Anime Launcher
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Launches ani-cli inside a themed floating Kitty window
# with a sub/dub selector, quality picker, and more.

ANICLI_BIN="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"

if [ ! -x "$ANICLI_BIN" ]; then
    command -v notify-send &>/dev/null && \
        notify-send "Hydra Anime" "ani-cli not found. Fetching..." -i video-player
    mkdir -p "$HOME/.local/bin"
    curl -sL https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli \
        -o "$HOME/.local/bin/ani-cli"
    chmod +x "$HOME/.local/bin/ani-cli"
    ANICLI_BIN="$HOME/.local/bin/ani-cli"
fi

ANIME_CONF="$HOME/.config/kitty/hydra-anime.conf"

# Generate themed kitty override config if it doesn't exist
if [ ! -f "$ANIME_CONF" ]; then
    mkdir -p "$HOME/.config/kitty"
    cat > "$ANIME_CONF" << 'KITTYCONF'
# Hydra Anime – themed kitty config
font_family      JetBrains Mono
font_size        9.0
bold_font        auto
italic_font      auto

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

# Launch kitty with the anime theme, run interactive menu inside
exec kitty --class hydra-anime --title "Hydra Anime" \
    --config "$HOME/.config/kitty/kitty.conf" \
    --config "$ANIME_CONF" \
    bash -c '
    ANICLI="'"$ANICLI_BIN"'"
    SKIP_FLAG=""
    command -v ani-skip &>/dev/null && SKIP_FLAG="--skip"

    # ── Main menu ──
    MODE=$(printf "🔍 Search Anime (Sub)\n🔍 Search Anime (Dub)\n▶  Continue Watching\n⬇  Download Episode (Sub)\n⬇  Download Episode (Dub)" \
        | fzf --prompt="  Hydra Anime ▸ " --pointer="▶" --border=rounded --margin=1 --height=50% \
              --color="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff")

    [[ -z "$MODE" ]] && exit 0

    # ── Quality picker ──
    QUALITY=$(printf "1080p (Best)\n720p\n480p" \
        | fzf --prompt="  Quality ▸ " --pointer="▶" --border=rounded --margin=1 --height=40% \
              --color="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff")

    [[ -z "$QUALITY" ]] && exit 0
    QUALITY=$(echo "$QUALITY" | grep -oP "^\d+p")

    # ── Build flags ──
    FLAGS="-q $QUALITY $SKIP_FLAG"

    case "$MODE" in
        *"Continue"*)      exec "$ANICLI" $FLAGS -c ;;
        *"Sub"*"Download"*|*"Download"*"Sub"*) exec "$ANICLI" $FLAGS -d ;;
        *"Dub"*"Download"*|*"Download"*"Dub"*) exec "$ANICLI" $FLAGS -d --dub ;;
        *"Dub"*)           exec "$ANICLI" $FLAGS --dub ;;
        *)                 exec "$ANICLI" $FLAGS ;;
    esac
'
