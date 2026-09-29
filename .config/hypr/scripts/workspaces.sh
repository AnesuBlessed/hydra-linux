#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CACHING & MIGRATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# ============================================================================
# 1. SINGLETON PER MONITOR
# One daemon per output, each writing its own state file. `flock` replaces the
# old pgrep-and-kill approach, which made every new instance murder the others.
# ============================================================================
RAW_MONITOR="${1:-global}"
# Output names look like "eDP-1" / "DP-2"; strip anything unsafe for a filename.
MONITOR_NAME=$(printf '%s' "$RAW_MONITOR" | tr -c 'A-Za-z0-9._-' '_')
[ -z "$MONITOR_NAME" ] && MONITOR_NAME="global"

LOCK_FILE="$QS_RUN_WORKSPACES/workspaces_${MONITOR_NAME}.lock"
exec 200>"$LOCK_FILE"

# A Quickshell reload spawns the replacement while the old instance is still
# unwinding. Retry briefly so the new daemon wins the lock instead of exiting
# and leaving this monitor's workspace bar permanently stale.
LOCK_TRIES=0
until flock -n 200; do
    LOCK_TRIES=$((LOCK_TRIES + 1))
    if [ "$LOCK_TRIES" -ge 50 ]; then
        # The previous holder is alive but wedged. Take the lock over rather
        # than leaving this monitor with no writer at all.
        OLD_PID="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            kill -TERM "$OLD_PID" 2>/dev/null
            sleep 1
            kill -0 "$OLD_PID" 2>/dev/null && kill -KILL "$OLD_PID" 2>/dev/null
        fi
        # Bounded so we never spin forever on an unkillable holder.
        flock -w 5 200 || exit 0
        break
    fi
    sleep 0.1
done
printf '%s' "$$" > "$LOCK_FILE"

# Cleanly kill immediate children (like socat) when the script exits normally
cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
# The network toggle starts a background bluetooth scan that must be killed
# explicitly. Only run this once per session, not once per monitor.
BT_PID_FILE="$QS_RUN_WORKSPACES/bt_scan_pid"
BT_ONCE_MARKER="$QS_RUN_WORKSPACES/.bt_cleanup_done"

if [ ! -e "$BT_ONCE_MARKER" ]; then
    : > "$BT_ONCE_MARKER"
    if [ -f "$BT_PID_FILE" ]; then
        kill $(cat "$BT_PID_FILE") 2>/dev/null
        rm -f "$BT_PID_FILE"
    fi
    (timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
fi
# ---------------------------------------------

# Configuration: Parse from settings.json dynamically, fallback to 8
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
SEQ_END=$(jq -r '.workspaceCount // 8' "$SETTINGS_FILE" 2>/dev/null)
# Double check it is a valid integer to prevent jq errors later
if ! [[ "$SEQ_END" =~ ^[0-9]+$ ]]; then
    SEQ_END=8
fi

print_workspaces() {
    # Get raw data with a timeout fallback
    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    if [ "$MONITOR_NAME" = "global" ]; then
        active=$(timeout 2 hyprctl activeworkspace -j 2>/dev/null | jq '.id')
    else
        active=$(timeout 2 hyprctl monitors -j 2>/dev/null | jq -r ".[] | select(.name == \"$MONITOR_NAME\") | .activeWorkspace.id")
    fi

    # Failsafe if hyprctl crashes to prevent jq from outputting errors
    if [ -z "$spaces" ] || [ -z "$active" ]; then return; fi

    # Generate the JSON and write it atomically to prevent UI flickering
    echo "$spaces" | jq --unbuffered --argjson a "$active" --arg end "$SEQ_END" -c '
        # Create a map of workspace ID -> workspace data for easy lookup
        (map( { (.id|tostring): . } ) | add) as $s
        |
        # Iterate from 1 to SEQ_END
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            # Determine state: active -> occupied -> empty
            (if $i == $a then "active"
             elif ($s[$i|tostring] != null and $s[$i|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |

            # Get window title for tooltip (if exists)
            (if $s[$i|tostring] != null then $s[$i|tostring].lastwindowtitle else "Empty" end) as $win |

            {
                id: $i,
                state: $state,
                tooltip: $win
            }
        )
    ' > "$QS_RUN_WORKSPACES/workspaces_${MONITOR_NAME}.tmp"
    
    mv "$QS_RUN_WORKSPACES/workspaces_${MONITOR_NAME}.tmp" "$QS_RUN_WORKSPACES/workspaces_${MONITOR_NAME}.json"
}

# Print initial state
print_workspaces

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Hyprland socket wrapped in an infinite loop. A slow heartbeat
# re-print keeps the bar correct if the socket drops or an event is missed.
# ============================================================================
HYPR_SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"

while true; do
    if [ -S "$HYPR_SOCKET" ]; then
        socat -u "UNIX-CONNECT:$HYPR_SOCKET" - 2>/dev/null | while read -r line; do
            case "$line" in
                workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|monitoradded*|monitorremoved*)

                    # -> THE FIX <-
                    # Hyprland emits HUNDREDS of events a second when you move/resize windows.
                    # This reads and discards all subsequent events arriving within a 50ms window.
                    # It bundles the storm into a single UI update, completely preventing CPU clogging!
                    while read -t 0.05 -r extra_line; do
                        continue
                    done

                    print_workspaces
                    ;;
            esac
        done
    fi
    sleep 1
done
