#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hydra Anime – runs inside kitty
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ANICLI="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"
HYDRA_ANIME_DIR="$HOME/.local/state/hydra-anime"
HYDRA_PREF="$HYDRA_ANIME_DIR/last_mode"
HYDRA_WATCHLIST="$HYDRA_ANIME_DIR/watchlist"
HIST_FILE="$HOME/.local/state/ani-cli/ani-hsts"
ANIME_BASE="$HOME/Videos/Anime"
MAX_HISTORY=50

mkdir -p "$HYDRA_ANIME_DIR" "$ANIME_BASE"
touch "$HYDRA_WATCHLIST"

# ── Colors ──
R='\033[0m'
PURPLE='\033[38;2;199;146;234m'
GREEN='\033[38;2;130;255;181m'
RED='\033[38;2;255;107;107m'
BLUE='\033[38;2;108;155;255m'
YELLOW='\033[38;2;255;217;61m'
DIM='\033[2m'
BOLD='\033[1m'

FZF_COLORS="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff"

# ── Skip intros detection ──
SKIP_FLAG=""
command -v ani-skip &>/dev/null && SKIP_FLAG="--skip"

# ══════════════════════════════════
# Main loop
# ══════════════════════════════════
while true; do
    clear

    # ── Header ──
    printf "${PURPLE}${BOLD}  ◈ Hydra Anime${R}\n"
    printf "${DIM}  ─────────────────────────────${R}\n"

    LAST_MODE="Sub"
    [ -f "$HYDRA_PREF" ] && LAST_MODE="$(cat "$HYDRA_PREF")"

    HIST_COUNT=$(wc -l < "$HIST_FILE" 2>/dev/null || echo 0)
    WL_COUNT=$(wc -l < "$HYDRA_WATCHLIST" 2>/dev/null || echo 0)

    STATUS="  ${DIM}${LAST_MODE}bed"
    [ -n "$SKIP_FLAG" ] && STATUS="${STATUS}  ${GREEN}✓${DIM} skip"
    STATUS="${STATUS}  ${DIM}${HIST_COUNT} watched  ${WL_COUNT} saved${R}"
    printf "%b\n\n" "$STATUS"

    # Trim history
    if [ -f "$HIST_FILE" ] && [ "$HIST_COUNT" -gt "$MAX_HISTORY" ]; then
        tail -n "$MAX_HISTORY" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
    fi

    # ── Main menu ──
    if [ "$LAST_MODE" = "Dub" ]; then
        MENU="Stream (Dub) *
Stream (Sub)
Continue Watching
Download
Watchlist
Next Episode
Clear History
Quit"
    else
        MENU="Stream (Sub) *
Stream (Dub)
Continue Watching
Download
Watchlist
Next Episode
Clear History
Quit"
    fi

    MODE=$(printf "%s" "$MENU" | fzf \
        --prompt="  ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=1 \
        --height=55% \
        --color="$FZF_COLORS")

    [[ -z "$MODE" || "$MODE" == "Quit" ]] && exit 0

    # ════════════════════════════════
    # Clear History
    # ════════════════════════════════
    if [[ "$MODE" == "Clear History" ]]; then
        printf "\n${YELLOW}  This will clear your entire watch history.${R}\n"
        printf "${PURPLE}  [y] Confirm  [n] Cancel ▸ ${R}"
        read -r CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            > "$HIST_FILE"
            printf "${GREEN}  ✓ History cleared${R}\n"
            sleep 1
        fi
        continue
    fi

    # ════════════════════════════════
    # Watchlist
    # ════════════════════════════════
    if [[ "$MODE" == "Watchlist" ]]; then
        while true; do
            clear
            printf "${PURPLE}${BOLD}  ◈ Watchlist${R}\n"
            printf "${DIM}  ─────────────────────────────${R}\n\n"

            WL_ACTION=$(printf "View watchlist\nAdd to watchlist\nRemove from watchlist\nBack" | fzf \
                --prompt="  ▸ " \
                --pointer="▶" \
                --border=rounded \
                --margin=1 \
                --height=40% \
                --color="$FZF_COLORS")

            case "$WL_ACTION" in
                "Add to watchlist")
                    printf "\n${BLUE}  Anime name: ${R}"
                    read -r WL_NAME
                    if [ -n "$WL_NAME" ]; then
                        echo "$WL_NAME" >> "$HYDRA_WATCHLIST"
                        printf "${GREEN}  ✓ Added: ${WL_NAME}${R}\n"
                        sleep 1
                    fi
                    ;;
                "View watchlist")
                    if [ -s "$HYDRA_WATCHLIST" ]; then
                        printf "\n"
                        nl -w3 -s"  " "$HYDRA_WATCHLIST"
                        printf "\n${PURPLE}  [Enter] Back ▸ ${R}"
                        read -r
                    else
                        printf "\n${DIM}  Watchlist is empty${R}\n"
                        sleep 1
                    fi
                    ;;
                "Remove from watchlist")
                    if [ -s "$HYDRA_WATCHLIST" ]; then
                        REMOVE=$(cat "$HYDRA_WATCHLIST" | fzf \
                            --prompt="  Remove ▸ " \
                            --pointer="▶" \
                            --border=rounded \
                            --margin=1 \
                            --height=40% \
                            --color="$FZF_COLORS")
                        if [ -n "$REMOVE" ]; then
                            grep -vxF "$REMOVE" "$HYDRA_WATCHLIST" > "${HYDRA_WATCHLIST}.tmp"
                            mv "${HYDRA_WATCHLIST}.tmp" "$HYDRA_WATCHLIST"
                            printf "${GREEN}  ✓ Removed: ${REMOVE}${R}\n"
                            sleep 1
                        fi
                    else
                        printf "\n${DIM}  Watchlist is empty${R}\n"
                        sleep 1
                    fi
                    ;;
                *) break ;;
            esac
        done
        continue
    fi

    # ════════════════════════════════
    # Next Episode Countdown
    # ════════════════════════════════
    if [[ "$MODE" == "Next Episode" ]]; then
        printf "\n${BLUE}  Anime name: ${R}"
        read -r NE_NAME
        if [ -n "$NE_NAME" ]; then
            "$ANICLI" -N "$NE_NAME" --no-detach
        fi
        printf "\n${PURPLE}  [Enter] Back to menu ▸ ${R}"
        read -r
        continue
    fi

    # ════════════════════════════════
    # Download
    # ════════════════════════════════
    if [[ "$MODE" == "Download" ]]; then
        DL_TYPE=$(printf "Download (Sub)\nDownload (Dub)" | fzf \
            --prompt="  Audio ▸ " \
            --pointer="▶" \
            --border=rounded \
            --margin=1 \
            --height=30% \
            --color="$FZF_COLORS")
        [[ -z "$DL_TYPE" ]] && continue

        DL_DUB=""
        [[ "$DL_TYPE" == *"Dub"* ]] && DL_DUB="--dub"

        DL_QUALITY=$(printf "1080p\n720p\n480p" | fzf \
            --prompt="  Quality ▸ " \
            --pointer="▶" \
            --border=rounded \
            --margin=1 \
            --height=30% \
            --color="$FZF_COLORS")
        [[ -z "$DL_QUALITY" ]] && continue

        printf "\n${BLUE}  Anime name (folder name): ${R}"
        read -r ANIME_NAME
        [[ -z "$ANIME_NAME" ]] && continue

        FOLDER_NAME=$(printf "%s" "$ANIME_NAME" | tr '<>:"/\|?*' '_' | sed 's/  */ /g; s/^ //; s/ $//')
        DL_DIR="$ANIME_BASE/$FOLDER_NAME"
        mkdir -p "$DL_DIR"

        printf "${BLUE}  Episodes (e.g. 1  or  1-12  or  1 2 5): ${R}"
        read -r EP_RANGE
        [[ -z "$EP_RANGE" ]] && continue

        printf "\n${GREEN}  ┌─────────────────────────────────────────┐${R}\n"
        printf "${GREEN}  │  Saving to: ~/Videos/Anime/%-13s│${R}\n" "$FOLDER_NAME"
        printf "${GREEN}  │  Episodes: %-29s│${R}\n" "$EP_RANGE"
        printf "${GREEN}  │  Quality:  %-29s│${R}\n" "$DL_QUALITY"
        printf "${GREEN}  │  Audio:    %-29s│${R}\n" "$([ -n "$DL_DUB" ] && echo "Dubbed" || echo "Subbed")"
        printf "${GREEN}  └─────────────────────────────────────────┘${R}\n\n"

        export ANI_CLI_DOWNLOAD_DIR="$DL_DIR"
        "$ANICLI" -q "$DL_QUALITY" $DL_DUB -d -e "$EP_RANGE" --no-detach "$ANIME_NAME"
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            FILE_COUNT=$(find "$DL_DIR" -name "*.mp4" 2>/dev/null | wc -l)
            printf "\n${GREEN}  ✓ Done – ${FILE_COUNT} file(s) in:${R}\n"
            printf "${DIM}    $DL_DIR${R}\n"
        else
            printf "\n${RED}  ✗ Download failed (code %d)${R}\n" "$EXIT_CODE"
        fi

        printf "\n${PURPLE}  [Enter] Back to menu  [q] Quit ▸ ${R}"
        read -r CHOICE
        [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0
        continue
    fi

    # ════════════════════════════════
    # Stream
    # ════════════════════════════════

    # Save sub/dub preference
    if [[ "$MODE" == *"Dub"* ]]; then
        echo "Dub" > "$HYDRA_PREF"
    elif [[ "$MODE" == *"Sub"* ]]; then
        echo "Sub" > "$HYDRA_PREF"
    fi

    QUALITY=$(printf "1080p\n720p\n480p" | fzf \
        --prompt="  Quality ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=1 \
        --height=35% \
        --color="$FZF_COLORS")

    [[ -z "$QUALITY" ]] && continue

    DUB_FLAG=""
    [[ "$MODE" == *"Dub"* ]] && DUB_FLAG="--dub"

    CONTINUE_FLAG=""
    [[ "$MODE" == *"Continue"* ]] && CONTINUE_FLAG="-c"

    printf "\n${DIM}  mpv keybinds: s=skip intro  Ctrl+1=Anime4K Light  Ctrl+2=Medium  Ctrl+0=Off${R}\n\n"

    "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG $CONTINUE_FLAG --no-detach
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        printf "\n${RED}  ✗ ani-cli exited with error (code %d)${R}\n" "$EXIT_CODE"
        printf "${DIM}  Source may be down or quality unavailable${R}\n"
    fi

    printf "\n${PURPLE}  [Enter] Back to menu  [q] Quit ▸ ${R}"
    read -r CHOICE
    [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0

done
