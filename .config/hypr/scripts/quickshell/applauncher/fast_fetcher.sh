#!/bin/bash
cache="$HOME/.cache/quickshell/applauncher_cache.json"
fetcher="$HOME/.config/hypr/scripts/quickshell/applauncher/app_fetcher.py"

if [ -f "$cache" ]; then
    cat "$cache"
    python3 "$fetcher" >/dev/null 2>&1 &
else
    python3 "$fetcher"
fi
