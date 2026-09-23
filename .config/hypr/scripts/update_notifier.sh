#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

INTERVAL=600
CACHE_FILE="$QS_CACHE_UPDATER/notified_version"
PENDING_FILE="$QS_CACHE_UPDATER/update_pending"

read_local_version() {
    local state_file
    for state_file in "$HOME/.local/state/hydra-linux-version" \
        "$HOME/.local/state/imperative-dots-version"; do
        if [[ -r "$state_file" ]]; then
            head -n 1 -- "$state_file" | tr -d '\r\n'
            return 0
        fi
    done
    return 1
}

while true; do
    LOCAL_VERSION=$(read_local_version 2>/dev/null || true)
    LOCAL_VERSION=${LOCAL_VERSION:-Unknown}

    REMOTE_VERSION=$(curl -m 5 -fsSL \
        https://raw.githubusercontent.com/AnesuBlessed/hydra-linux/main/version.txt \
        2>/dev/null | head -n 1 | tr -d '\r\n')

    if [[ -n "$REMOTE_VERSION" && "$LOCAL_VERSION" != "Unknown" && "$LOCAL_VERSION" != "$REMOTE_VERSION" ]]; then
        NEWEST=$(printf '%s\n' "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | tail -n 1)

        if [[ "$NEWEST" == "$REMOTE_VERSION" ]]; then
            touch -- "$PENDING_FILE"

            if [[ ! -f "$CACHE_FILE" ]] || [[ "$(cat -- "$CACHE_FILE")" != "$REMOTE_VERSION" ]]; then
                printf '%s\n' "$REMOTE_VERSION" > "$CACHE_FILE"
                notify-send -t 15000 -a 'Hydra Linux' -u normal \
                    'Update Available' \
                    "A new version ($REMOTE_VERSION) is ready! Click the update icon in the topbar to install."
            fi
        fi
    else
        rm -f -- "$PENDING_FILE"
    fi

    sleep "$INTERVAL"
done
