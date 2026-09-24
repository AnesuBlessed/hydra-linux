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
CYAN='\033[38;2;137;221;255m'
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

    LAST_MODE="Sub"
    [ -f "$HYDRA_PREF" ] && LAST_MODE="$(cat "$HYDRA_PREF")"

    HIST_COUNT=$(wc -l < "$HIST_FILE" 2>/dev/null || echo 0)
    WL_COUNT=$(grep -c . "$HYDRA_WATCHLIST" 2>/dev/null || echo 0)

    # Clean Header
    printf "${PURPLE}${BOLD}  ◈ HYDRA ANIME${R}\n"
    
    STATUS="${DIM}  ${LAST_MODE}bed"
    [ -n "$SKIP_FLAG" ] && STATUS="${STATUS}  ·  ${GREEN}auto-skip${DIM}"
    STATUS="${STATUS}  ·  ${HIST_COUNT} watched  ·  ${WL_COUNT} saved${R}"
    printf "%b\n\n" "$STATUS"

    # Trim history
    if [ -f "$HIST_FILE" ] && [ "$HIST_COUNT" -gt "$MAX_HISTORY" ]; then
        tail -n "$MAX_HISTORY" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
    fi

    # ── Main menu (Clean, perfectly aligned entries) ──
    MENU="Stream (Sub)
Stream (Dub)
Continue Watching
Watchlist
Download
Next Episode
Clear History
Quit"

    MODE=$(printf "%s" "$MENU" | fzf \
        --prompt="  ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=0,1 \
        --height=50% \
        --color="$FZF_COLORS")

    [[ -z "$MODE" || "$MODE" == "Quit" ]] && exit 0

    # ════════════════════════════════
    # Clear History
    # ════════════════════════════════
    if [[ "$MODE" == "Clear History" ]]; then
        printf "\n  ${YELLOW}This will delete your watch history.${R}\n"
        printf "  ${PURPLE}Confirm? [y/N] ▸ ${R}"
        read -r CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            > "$HIST_FILE"
            printf "\n  ${GREEN}✓ History cleared.${R}\n"
            sleep 1
        fi
        continue
    fi

    # ════════════════════════════════
    # Interactive Watchlist
    # ════════════════════════════════
    if [[ "$MODE" == "Watchlist" ]]; then
        while true; do
            clear
            WL_COUNT=$(grep -c . "$HYDRA_WATCHLIST" 2>/dev/null || echo 0)
            printf "${PURPLE}${BOLD}  ◈ WATCHLIST${R} ${DIM}(${WL_COUNT} saved)${R}\n\n"

            WL_ACTION=$(printf "▶ Stream from Watchlist\n✚ Add Anime\n🗑 Remove Anime\nBack" | fzf \
                --prompt="  Watchlist ▸ " \
                --pointer="▶" \
                --border=rounded \
                --margin=0,1 \
                --height=45% \
                --color="$FZF_COLORS")

            case "$WL_ACTION" in
                "✚ Add Anime")
                    printf "\n  ${BLUE}Anime Title: ${R}"
                    read -r WL_NAME
                    if [ -n "$WL_NAME" ]; then
                        echo "$WL_NAME" >> "$HYDRA_WATCHLIST"
                        printf "  ${GREEN}✓ Added '${WL_NAME}'${R}\n"
                        sleep 1
                    fi
                    ;;

                "▶ Stream from Watchlist")
                    if [ ! -s "$HYDRA_WATCHLIST" ]; then
                        printf "\n  ${YELLOW}Watchlist is empty.${R}\n"
                        sleep 1.5
                        continue
                    fi

                    SELECTED_ANIME=$(cat "$HYDRA_WATCHLIST" | fzf \
                        --prompt="  Title ▸ " \
                        --pointer="▶" \
                        --border=rounded \
                        --margin=0,1 \
                        --height=45% \
                        --color="$FZF_COLORS")

                    [[ -z "$SELECTED_ANIME" ]] && continue

                    # Select Sub / Dub
                    WL_AUDIO=$(printf "Subbed\nDubbed" | fzf \
                        --prompt="  Audio ▸ " \
                        --pointer="▶" \
                        --border=rounded \
                        --margin=0,1 \
                        --height=30% \
                        --color="$FZF_COLORS")

                    [[ -z "$WL_AUDIO" ]] && continue
                    WL_DUB_FLAG=""
                    [[ "$WL_AUDIO" == "Dubbed" ]] && WL_DUB_FLAG="--dub"

                    # Quality
                    WL_QUALITY=$(printf "1080p\n720p\n480p" | fzf \
                        --prompt="  Quality ▸ " \
                        --pointer="▶" \
                        --border=rounded \
                        --margin=0,1 \
                        --height=30% \
                        --color="$FZF_COLORS")

                    [[ -z "$WL_QUALITY" ]] && continue

                    # Episode Jump Prompt
                    printf "\n  ${BLUE}Episode # (Enter for list, or type e.g. 12): ${R}"
                    read -r WL_EP
                    WL_EP_FLAG=""
                    if [ -n "$WL_EP" ]; then
                        WL_EP_FLAG="-e $WL_EP"
                    fi

                    printf "\n  ${DIM}Connecting ${SELECTED_ANIME}...${R}\n\n"
                    "$ANICLI" -q "$WL_QUALITY" $SKIP_FLAG $WL_DUB_FLAG $WL_EP_FLAG --no-detach "$SELECTED_ANIME"
                    EXIT_CODE=$?

                    if [ $EXIT_CODE -ne 0 ]; then
                        printf "\n  ${RED}✗ Stream finished (exit code %d)${R}\n" "$EXIT_CODE"
                    fi

                    printf "\n  ${PURPLE}[Enter] Back  [q] Quit ▸ ${R}"
                    read -r CHOICE
                    [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0
                    ;;

                "🗑 Remove Anime")
                    if [ -s "$HYDRA_WATCHLIST" ]; then
                        REMOVE=$(cat "$HYDRA_WATCHLIST" | fzf \
                            --prompt="  Remove ▸ " \
                            --pointer="▶" \
                            --border=rounded \
                            --margin=0,1 \
                            --height=45% \
                            --color="$FZF_COLORS")
                        if [ -n "$REMOVE" ]; then
                            grep -vxF "$REMOVE" "$HYDRA_WATCHLIST" > "${HYDRA_WATCHLIST}.tmp"
                            mv "${HYDRA_WATCHLIST}.tmp" "$HYDRA_WATCHLIST"
                            printf "  ${GREEN}✓ Removed '${REMOVE}'${R}\n"
                            sleep 1
                        fi
                    else
                        printf "\n  ${YELLOW}Watchlist is empty.${R}\n"
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
        printf "\n  ${BLUE}Anime Title: ${R}"
        read -r NE_NAME
        if [ -n "$NE_NAME" ]; then
            printf "\n"
            "$ANICLI" -N "$NE_NAME" --no-detach
        fi
        printf "\n  ${PURPLE}[Enter] Back ▸ ${R}"
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
            --margin=0,1 \
            --height=30% \
            --color="$FZF_COLORS")
        [[ -z "$DL_TYPE" ]] && continue

        DL_DUB=""
        [[ "$DL_TYPE" == *"Dub"* ]] && DL_DUB="--dub"

        DL_QUALITY=$(printf "1080p\n720p\n480p" | fzf \
            --prompt="  Quality ▸ " \
            --pointer="▶" \
            --border=rounded \
            --margin=0,1 \
            --height=30% \
            --color="$FZF_COLORS")
        [[ -z "$DL_QUALITY" ]] && continue

        printf "\n  ${BLUE}Anime Title (Main Folder): ${R}"
        read -r ANIME_NAME
        [[ -z "$ANIME_NAME" ]] && continue

        FOLDER_NAME=$(printf "%s" "$ANIME_NAME" | tr '<>:"/\|?*' '_' | sed 's/  */ /g; s/^ //; s/ $//')

        printf "  ${BLUE}Season / Subfolder (Enter for main, or e.g. Season 2): ${R}"
        read -r SEASON_NAME

        if [ -n "$SEASON_NAME" ]; then
            SEASON_FOLDER=$(printf "%s" "$SEASON_NAME" | tr '<>:"/\|?*' '_' | sed 's/  */ /g; s/^ //; s/ $//')
            DL_DIR="$ANIME_BASE/$FOLDER_NAME/$SEASON_FOLDER"
            DISPLAY_PATH="~/Videos/Anime/$FOLDER_NAME/$SEASON_FOLDER"
        else
            DL_DIR="$ANIME_BASE/$FOLDER_NAME"
            DISPLAY_PATH="~/Videos/Anime/$FOLDER_NAME"
        fi

        mkdir -p "$DL_DIR"

        # Check existing files
        EXISTING_FILES=$(find "$DL_DIR" -maxdepth 1 -name "*.mp4" 2>/dev/null | wc -l)
        if [ "$EXISTING_FILES" -gt 0 ]; then
            printf "\n  ${YELLOW}ℹ ${EXISTING_FILES} episode(s) already in destination.${R}\n"
            printf "  ${DIM}yt-dlp will automatically skip completed files.${R}\n"
        fi

        printf "\n  ${BLUE}Episodes (e.g. 1  or  1-12  or  1 2 5): ${R}"
        read -r EP_RANGE
        [[ -z "$EP_RANGE" ]] && continue

        printf "\n  ${GREEN}Saving to:${R} ${DISPLAY_PATH}\n"
        printf "  ${GREEN}Episodes:${R} ${EP_RANGE}  ·  ${GREEN}Quality:${R} ${DL_QUALITY}  ·  ${GREEN}Audio:${R} $([ -n "$DL_DUB" ] && echo "Dubbed" || echo "Subbed")\n\n"

        export ANI_CLI_DOWNLOAD_DIR="$DL_DIR"
        "$ANICLI" -q "$DL_QUALITY" $DL_DUB -d -e "$EP_RANGE" --no-detach "$ANIME_NAME"
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            FILE_COUNT=$(find "$DL_DIR" -name "*.mp4" 2>/dev/null | wc -l)
            printf "\n  ${GREEN}✓ Download finished (${FILE_COUNT} files in folder).${R}\n"
        else
            printf "\n  ${RED}✗ Download exited with code %d${R}\n" "$EXIT_CODE"
        fi

        printf "\n  ${PURPLE}[Enter] Back  [q] Quit ▸ ${R}"
        read -r CHOICE
        [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0
        continue
    fi

    # ════════════════════════════════
    # Stream (Standard & Episode Jump)
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
        --margin=0,1 \
        --height=35% \
        --color="$FZF_COLORS")

    [[ -z "$QUALITY" ]] && continue

    DUB_FLAG=""
    [[ "$MODE" == *"Dub"* ]] && DUB_FLAG="--dub"

    CONTINUE_FLAG=""
    EP_JUMP_FLAG=""

    if [[ "$MODE" == *"Continue"* ]]; then
        CONTINUE_FLAG="-c"
    else
        printf "\n  ${BLUE}Episode # (Enter for list, or type e.g. 12): ${R}"
        read -r EP_INPUT
        if [ -n "$EP_INPUT" ]; then
            EP_JUMP_FLAG="-e $EP_INPUT"
        fi
    fi

    printf "\n  ${DIM}mpv hotkeys: s=skip intro  Ctrl+1=Anime4K Light  Ctrl+2=Medium  Ctrl+0=Off${R}\n\n"

    "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG $CONTINUE_FLAG $EP_JUMP_FLAG --no-detach
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        printf "\n  ${RED}✗ Stream finished (exit code %d)${R}\n" "$EXIT_CODE"
        printf "  ${DIM}Source may be down or requested quality unavailable.${R}\n"
    fi

    printf "\n  ${PURPLE}[Enter] Back  [q] Quit ▸ ${R}"
    read -r CHOICE
    [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0

done
