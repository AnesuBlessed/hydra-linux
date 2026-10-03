#!/usr/bin/env bash
# Hydra Linux - Laptop Lid Switch Handler
# Prevents screen shutdown / clamshell disconnect when in Turbo mode or when no external display is attached.

ACTION="$1"
PROFILE=$(powerprofilesctl get 2>/dev/null || echo "balanced")

# In Turbo mode, keep display alive and never close screen
if [ "$PROFILE" = "performance" ]; then
    exit 0
fi

if [ "$ACTION" = "close" ]; then
    # Clamshell Mode: Only disable laptop internal panel if an external monitor is actually active
    EXT_COUNT=$(hyprctl monitors -j 2>/dev/null | jq '[.[] | select(.name != "eDP-1")] | length' 2>/dev/null || echo 0)
    if [ "$EXT_COUNT" -gt 0 ]; then
        hyprctl keyword monitor "eDP-1, disable"
    fi
elif [ "$ACTION" = "open" ]; then
    hyprctl reload
fi
