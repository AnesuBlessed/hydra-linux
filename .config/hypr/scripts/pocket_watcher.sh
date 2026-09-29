#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "pocket"

# File to store banishment times in secure user runtime directory
STATE_FILE="${QS_RUN_POCKET:-$QS_RUN_DIR/pocket}/dimension_state"
touch "$STATE_FILE"

while true; do
    # Get all windows on the special workspace
    BANISHED=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.workspace.name == "special:magic") | .address + "|" + .class' 2>/dev/null)

    # Read current state
    declare -A current_state=()
    if [[ -r "$STATE_FILE" ]]; then
        while IFS=, read -r addr timestamp; do
            if [ -n "$addr" ]; then current_state["$addr"]="$timestamp"; fi
        done < "$STATE_FILE"
    fi

    # Create new state
    declare -A new_state=()
    current_time=$(date +%s)

    for entry in $BANISHED; do
        addr="${entry%|*}"
        class="${entry#*|}"

        if [ -n "${current_state[$addr]}" ]; then
            # Window was already banished, keep its timestamp
            new_state["$addr"]="${current_state[$addr]}"
            
            # Check if it has been banished for > 30 minutes (1800 seconds)
            diff=$(( current_time - ${new_state[$addr]} ))
            if [ $diff -ge 1800 ]; then
                # Reset timestamp so it doesn't spam every minute, but will remind again in 30 mins
                new_state["$addr"]="$current_time"
                
                # Send notification with action
                # If they click "Welcome Back" (restore), we move it to the active workspace
                ACTION=$(notify-send -A "restore=Welcome Back" -i "$class" -a "Pocket Dimension" "Banished App" "${class} has been banished for 30 minutes. Shall we welcome it back to our realm?")
                if [ "$ACTION" == "restore" ]; then
                    hyprctl dispatch movetoworkspace +0,address:${addr} >/dev/null 2>&1
                    # Remove from state since it's restored
                    unset "new_state[$addr]"
                fi
            fi
        else
            # New banishment, record timestamp
            new_state["$addr"]="$current_time"
        fi
    done

    # Save new state
    > "$STATE_FILE"
    for addr in "${!new_state[@]}"; do
        echo "$addr,${new_state[$addr]}" >> "$STATE_FILE"
    done

    sleep 60
done
