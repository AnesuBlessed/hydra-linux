#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ◈ Hydra Anime Launcher
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Launches ani-cli inside a themed floating Kitty window
# with sub/dub memory, quality picker, download progress, and history management.

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
    HYDRA_ANIME_DIR="$HOME/.local/state/hydra-anime"
    HYDRA_PREF="$HYDRA_ANIME_DIR/last_mode"
    HIST_FILE="$HOME/.local/state/ani-cli/ani-hsts"
    DOWNLOAD_DIR="$HOME/Videos/Anime"
    MAX_HISTORY=50

    mkdir -p "$HYDRA_ANIME_DIR" "$DOWNLOAD_DIR"

    # ── Read last sub/dub preference ──
    LAST_MODE="Sub"
    [ -f "$HYDRA_PREF" ] && LAST_MODE="$(cat "$HYDRA_PREF")"

    # ── Trim history to last N entries for snappiness ──
    if [ -f "$HIST_FILE" ] && [ "$(wc -l < "$HIST_FILE")" -gt "$MAX_HISTORY" ]; then
        tail -n "$MAX_HISTORY" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
    fi

    # ── Skip flag (auto-detect ani-skip) ──
    SKIP_FLAG=""
    if command -v ani-skip &>/dev/null; then
        SKIP_FLAG="--skip"
        printf "\033[38;2;130;255;181m✓ ani-skip detected – intros will be skipped automatically\033[0m\n\n"
    else
        printf "\033[38;2;255;107;107m✗ ani-skip not installed – intros will play normally\033[0m\n"
        printf "  \033[2mInstall: yay -S ani-skip-git\033[0m\n\n"
    fi

    # ── Build menu with last preference highlighted ──
    if [ "$LAST_MODE" = "Dub" ]; then
        MENU=$(printf "🔍 Search Anime (Dub) ★\n🔍 Search Anime (Sub)\n▶  Continue Watching (Dub) ★\n▶  Continue Watching (Sub)\n⬇  Download Episode (Dub) ★\n⬇  Download Episode (Sub)")
    else
        MENU=$(printf "🔍 Search Anime (Sub) ★\n🔍 Search Anime (Dub)\n▶  Continue Watching (Sub) ★\n▶  Continue Watching (Dub)\n⬇  Download Episode (Sub)\n⬇  Download Episode (Dub)")
    fi

    MODE=$(printf "%s" "$MENU" \
        | fzf --prompt="  Hydra Anime ▸ " --pointer="▶" --border=rounded --margin=1 --height=60% \
              --color="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff" \
              --header="  Last: ${LAST_MODE}bed  │  History: $(wc -l < "$HIST_FILE" 2>/dev/null || echo 0) entries")

    [[ -z "$MODE" ]] && exit 0

    # ── Save preference ──
    if [[ "$MODE" == *"Dub"* ]]; then
        echo "Dub" > "$HYDRA_PREF"
    else
        echo "Sub" > "$HYDRA_PREF"
    fi

    # ── Quality picker ──
    QUALITY=$(printf "1080p (Best)\n720p\n480p" \
        | fzf --prompt="  Quality ▸ " --pointer="▶" --border=rounded --margin=1 --height=40% \
              --color="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c")

    [[ -z "$QUALITY" ]] && exit 0
    QUALITY=$(echo "$QUALITY" | grep -oP "^\d+p")

    # ── Build flags ──
    DUB_FLAG=""
    [[ "$MODE" == *"Dub"* ]] && DUB_FLAG="--dub"

    # ── Execute ──
    run_ani() {
        "$@"
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            printf "\n\033[38;2;255;107;107m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
            printf "\033[38;2;255;107;107m  ✗ ani-cli exited with error (code %d)\033[0m\n" "$EXIT_CODE"
            printf "\033[38;2;255;107;107m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n"
            printf "\033[2m  This can happen when:\033[0m\n"
            printf "\033[2m  • The anime source is temporarily unavailable\033[0m\n"
            printf "\033[2m  • The selected quality is not available for this title\033[0m\n"
            printf "\033[2m  • Your network connection dropped\033[0m\n\n"
            printf "\033[38;2;199;146;234m  Press Enter to close, or type \"r\" to retry ▸ \033[0m"
            read -r RETRY
            if [[ "$RETRY" == "r" || "$RETRY" == "R" ]]; then
                run_ani "$@"
            fi
        fi
    }

    case "$MODE" in
        *"Continue"*)
            printf "\n\033[38;2;108;155;255m⟳ Loading watch history...\033[0m\n"
            run_ani "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG -c
            ;;
        *"Download"*)
            printf "\n\033[38;2;255;217;61m⬇ Downloads will be saved to: %s\033[0m\n" "$DOWNLOAD_DIR"
            printf "\033[38;2;130;255;181m  Using yt-dlp with 16 parallel fragments for fast downloads\033[0m\n\n"
            export ANI_CLI_DOWNLOAD_DIR="$DOWNLOAD_DIR"
            run_ani "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG -d --no-detach
            ;;
        *)
            run_ani "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG --no-detach
            ;;
    esac
'
