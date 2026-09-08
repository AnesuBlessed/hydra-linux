#!/usr/bin/env bash

# Prevent duplicate lock processes from crashing Wayland session lock
if pgrep -f "quickshell.*Lock.qml" >/dev/null 2>&1; then
    exit 0
fi

# Source and initialize quickshell dynamic caching
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "lock"

quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
