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

FZF_COLORS="bg+:#1a1a2e,fg+:#c792ea,pointer:#c792ea,prompt:#82ffb5,border:#3a3a5c,header:#6c9bff"

# ── Read last preference ──
LAST_MODE="Sub"
[ -f "$HYDRA_PREF" ] && LAST_MODE="$(cat "$HYDRA_PREF")"

# ── Trim history ──
if [ -f "$HIST_FILE" ] && [ "$(wc -l < "$HIST_FILE" 2>/dev/null)" -gt "$MAX_HISTORY" ]; then
    tail -n "$MAX_HISTORY" "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
fi

# ── Skip intros detection ──
SKIP_FLAG=""
if command -v ani-skip &>/dev/null; then
    SKIP_FLAG="--skip"
    printf "${GREEN}✓ ani-skip detected${R}\n"
else
    printf "${DIM}tip: yay -S ani-skip-git for auto intro skipping${R}\n"
fi

HIST_COUNT=$(wc -l < "$HIST_FILE" 2>/dev/null || echo 0)
printf "${DIM}history: ${HIST_COUNT} entries  │  preference: ${LAST_MODE}bed${R}\n\n"

# ── Main menu ──
if [ "$LAST_MODE" = "Dub" ]; then
    MENU="Stream (Dub) ★
Stream (Sub)
Continue Watching"
else
    MENU="Stream (Sub) ★
Stream (Dub)
Continue Watching"
fi

MODE=$(printf "%s" "$MENU" | fzf \
    --prompt="  Hydra Anime ▸ " \
    --pointer="▶" \
    --border=rounded \
    --margin=1 \
    --height=40% \
    --color="$FZF_COLORS")

[[ -z "$MODE" ]] && exit 0

# ── Save preference ──
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

[[ -z "$QUALITY" ]] && exit 0

# ── Build flags ──
DUB_FLAG=""
[[ "$MODE" == *"Dub"* ]] && DUB_FLAG="--dub"

CONTINUE_FLAG=""
[[ "$MODE" == *"Continue"* ]] && CONTINUE_FLAG="-c"

printf "\n"

# ── Run with error handling ──
while true; do
    "$ANICLI" -q "$QUALITY" $SKIP_FLAG $DUB_FLAG $CONTINUE_FLAG --no-detach
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        printf "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
        printf "${RED}  ✗ ani-cli exited with error (code %d)${R}\n" "$EXIT_CODE"
        printf "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n\n"
        printf "${DIM}  • Source may be temporarily down${R}\n"
        printf "${DIM}  • Quality might not be available${R}\n"
        printf "${DIM}  • Network may have dropped${R}\n\n"
        printf "${PURPLE}  [r] Retry  [q] Quit ▸ ${R}"
        read -r CHOICE
        case "$CHOICE" in
            r|R) continue ;;
            *) exit 0 ;;
        esac
    else
        break
    fi
done
