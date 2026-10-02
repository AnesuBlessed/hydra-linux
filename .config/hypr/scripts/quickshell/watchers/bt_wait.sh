#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_bt_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null
trap 'rm -f "$PIPE"; kill $(jobs -p) 2>/dev/null; exit 0' EXIT INT TERM
gdbus monitor --system --dest org.bluez 2>/dev/null | grep --line-buffered -E "Connected|Powered" > "$PIPE" &
read -t 60 -r _ < "$PIPE"
