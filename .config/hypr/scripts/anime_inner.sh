#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hydra Anime – runs inside kitty
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ANICLI="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"
HYDRA_ANIME_DIR="$HOME/.local/state/hydra-anime"
HYDRA_PREF="$HYDRA_ANIME_DIR/last_mode"
HIST_FILE="$HOME/.local/state/ani-cli/ani-hsts"
ANIME_BASE="$HOME/Videos/Anime"
MAX_HISTORY=50

mkdir -p "$HYDRA_ANIME_DIR" "$ANIME_BASE"

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

# ── Skip intros detection (once) ──
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

    if [ -n "$SKIP_FLAG" ]; then
        printf "  ${GREEN}✓${R} ${DIM}ani-skip active${R}"
    fi

    # Read preference
    LAST_MODE="Sub"
    [ -f "$HYDRA_PREF" ] && LAST_MODE="$(cat "$HYDRA_PREF")"

    HIST_COUNT=$(wc -l < "$HIST_FILE" 2>/dev/null || echo 0)
    printf "  ${DIM}│  ${LAST_MODE}bed  │  ${HIST_COUNT} in history${R}\n\n"

    # Trim history
    if [ -f "$HIST_FILE" ] && [ "$HIST_COUNT" -gt "$MAX_HISTORY" ]; then
        tail -n "$MAX_HISTORY" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
    fi

    # ── Main menu ──
    if [ "$LAST_MODE" = "Dub" ]; then
        MENU="Stream (Dub) ★
Stream (Sub)
Continue Watching
Download Anime
Clear History
Quit"
    else
        MENU="Stream (Sub) ★
Stream (Dub)
Continue Watching
Download Anime
Clear History
Quit"
    fi

    MODE=$(printf "%s" "$MENU" | fzf \
        --prompt="  ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=1 \
        --height=50% \
        --color="$FZF_COLORS")

    [[ -z "$MODE" || "$MODE" == "Quit" ]] && exit 0

    # ── Clear History ──
    if [[ "$MODE" == "Clear History" ]]; then
        printf "\n${YELLOW}  ⚠ This will clear your entire watch history.${R}\n"
        printf "${PURPLE}  [y] Confirm  [n] Cancel ▸ ${R}"
        read -r CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            > "$HIST_FILE"
            printf "${GREEN}  ✓ History cleared${R}\n"
            sleep 1
        fi
        continue
    fi

    # ── Download Anime ──
    if [[ "$MODE" == "Download Anime" ]]; then
        # Sub or Dub for download
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

        # Quality
        DL_QUALITY=$(printf "1080p\n720p\n480p" | fzf \
            --prompt="  Quality ▸ " \
            --pointer="▶" \
            --border=rounded \
            --margin=1 \
            --height=30% \
            --color="$FZF_COLORS")
        [[ -z "$DL_QUALITY" ]] && continue

        # Anime name for folder
        printf "\n${BLUE}  Enter anime name (for folder): ${R}"
        read -r ANIME_NAME
        [[ -z "$ANIME_NAME" ]] && continue

        # Sanitize folder name
        FOLDER_NAME=$(printf "%s" "$ANIME_NAME" | tr '<>:"/\|?*' '_' | sed 's/  */ /g; s/^ //; s/ $//')
        DL_DIR="$ANIME_BASE/$FOLDER_NAME"
        mkdir -p "$DL_DIR"

        # Episode range
        printf "${BLUE}  Episode range (e.g. 1  or  1-12  or  1 2 5): ${R}"
        read -r EP_RANGE
        [[ -z "$EP_RANGE" ]] && continue

        printf "\n${GREEN}  ┌─────────────────────────────────────────┐${R}\n"
        printf "${GREEN}  │  Downloading to:                        │${R}\n"
        printf "${GREEN}  │  ~/Videos/Anime/%-24s│${R}\n" "$FOLDER_NAME"
        printf "${GREEN}  │  Episodes: %-29s│${R}\n" "$EP_RANGE"
        printf "${GREEN}  │  Quality: %-30s│${R}\n" "$DL_QUALITY"
        printf "${GREEN}  │  Audio: %-32s│${R}\n" "$([ -n "$DL_DUB" ] && echo "Dubbed" || echo "Subbed")"
        printf "${GREEN}  └─────────────────────────────────────────┘${R}\n\n"

        export ANI_CLI_DOWNLOAD_DIR="$DL_DIR"
        "$ANICLI" -q "$DL_QUALITY" $DL_DUB -d -e "$EP_RANGE" --no-detach "$ANIME_NAME"
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            FILE_COUNT=$(find "$DL_DIR" -name "*.mp4" 2>/dev/null | wc -l)
            printf "\n${GREEN}  ✓ Download complete – ${FILE_COUNT} file(s) in:${R}\n"
            printf "${DIM}    $DL_DIR${R}\n"
        else
            printf "\n${RED}  ✗ Download failed (code %d)${R}\n" "$EXIT_CODE"
        fi

        printf "\n${PURPLE}  [Enter] Back to menu  [q] Quit ▸ ${R}"
        read -r CHOICE
        [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0
        continue
    fi

    # ── Save sub/dub preference ──
    if [[ "$MODE" == *"Dub"* ]]; then
        echo "Dub" > "$HYDRA_PREF"
    elif [[ "$MODE" == *"Sub"* ]]; then
        echo "Sub" > "$HYDRA_PREF"
    fi

    # ── Quality ──
    QUALITY=$(printf "1080p\n720p\n480p" | fzf \
        --prompt="  Quality ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=1 \
        --height=35% \
        --color="$FZF_COLORS")

    [[ -z "$QUALITY" ]] && continue

    # ── Build flags ──
    DUB_FLAG=""
    [[ "$MODE" == *"Dub"* ]] && DUB_FLAG="--dub"

    CONTINUE_FLAG=""
    [[ "$MODE" == *"Continue"* ]] && CONTINUE_FLAG="-c"

    printf "\n"

    # ── Run ani-cli ──
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
