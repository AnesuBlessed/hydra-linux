#!/usr/bin/env bash

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    DETECTED_WAYLAND=$(find "${XDG_RUNTIME_DIR}" -maxdepth 1 -name "wayland-*" -type s 2>/dev/null | head -n1 | xargs -r basename)
    export WAYLAND_DISPLAY="${DETECTED_WAYLAND:-wayland-1}"
fi

if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
    export QS_RUN_DIR="$XDG_RUNTIME_DIR/quickshell"
else
    export QS_RUN_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/run"
fi
export QS_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
export QS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
export QS_LOG_DIR="$QS_RUN_DIR/logs"

mkdir -p "$QS_CACHE_DIR" "$QS_STATE_DIR" "$QS_RUN_DIR" "$QS_LOG_DIR"
chmod 700 "$QS_RUN_DIR" "$QS_LOG_DIR"
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
QS_DIR="$SCRIPT_DIR/quickshell"

# Function to dynamically create and export cache directories for ANY module by request
qs_ensure_cache() {
    local WIDGET_NAME="$1"
    local WIDGET_UPPER
    WIDGET_UPPER=$(echo "$WIDGET_NAME" | tr '[:lower:]' '[:upper:]')

    local WIDGET_CACHE="$QS_CACHE_DIR/$WIDGET_NAME"
    local WIDGET_STATE="$QS_STATE_DIR/$WIDGET_NAME"
    local WIDGET_RUN="$QS_RUN_DIR/$WIDGET_NAME"

    mkdir -p "$WIDGET_CACHE" "$WIDGET_STATE" "$WIDGET_RUN"
    chmod 700 "$WIDGET_RUN"

    export "QS_CACHE_${WIDGET_UPPER}=$WIDGET_CACHE"
    export "QS_STATE_${WIDGET_UPPER}=$WIDGET_STATE"
    export "QS_RUN_${WIDGET_UPPER}=$WIDGET_RUN"
}

# Pre-initialize for all existing QML widget folders in the main directory
if [[ -d "$QS_DIR" ]]; then
    for dir in "$QS_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        WIDGET_NAME=$(basename -- "$dir")
        qs_ensure_cache "$WIDGET_NAME"
    done
fi
qs_ensure_cache "wallpaper_picker"
