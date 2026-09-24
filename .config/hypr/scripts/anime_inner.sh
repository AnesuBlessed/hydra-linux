#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hydra Anime – runs inside kitty
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ANICLI="$(command -v ani-cli 2>/dev/null || echo "$HOME/.local/bin/ani-cli")"
HYDRA_ANIME_DIR="$HOME/.local/state/hydra-anime"
HYDRA_PREF="$HYDRA_ANIME_DIR/last_mode"
HIST_FILE="$HOME/.local/state/ani-cli/ani-hsts"
MAX_HISTORY=50

mkdir -p "$HYDRA_ANIME_DIR"

# ── Colors ──
R='\033[0m'
PURPLE='\033[38;2;199;146;234m'
GREEN='\033[38;2;130;255;181m'
RED='\033[38;2;255;107;107m'
BLUE='\033[38;2;108;155;255m'
DIM='\033[2m'
BOLD='\033[1m'

FZF_COLORS="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff"

# ── Skip intros detection (once) ──
SKIP_FLAG=""
command -v ani-skip &>/dev/null && SKIP_FLAG="--skip"

# ══════════════════════════════════
# Main loop – keeps you in the app
# ══════════════════════════════════
while true; do
    clear

    # ── Header ──
    printf "${PURPLE}${BOLD}  ◈ Hydra Anime${R}\n"
    printf "${DIM}  ─────────────────────────────${R}\n"

    if [ -n "$SKIP_FLAG" ]; then
        printf "  ${GREEN}✓${R} ${DIM}ani-skip active${R}"
    else
        printf "  ${DIM}tip: yay -S ani-skip-git${R}"
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
Quit"
    else
        MENU="Stream (Sub) ★
Stream (Dub)
Continue Watching
Quit"
    fi

    MODE=$(printf "%s" "$MENU" | fzf \
        --prompt="  ▸ " \
        --pointer="▶" \
        --border=rounded \
        --margin=1 \
        --height=45% \
        --color="$FZF_COLORS")

    [[ -z "$MODE" || "$MODE" == "Quit" ]] && exit 0

    # Save preference
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

    [[ -z "$QUALITY" ]] && continue  # back to menu if cancelled

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

    # After finishing or error, prompt to continue
    printf "\n${PURPLE}  [Enter] Back to menu  [q] Quit ▸ ${R}"
    read -r CHOICE
    [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && exit 0

done
