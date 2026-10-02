#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/../../caching.sh"
qs_ensure_cache "network"

# Zero-latency hardware presence check via sysfs (Instant, no nmcli hang)
if ! ls -1d /sys/class/net/*/wireless &>/dev/null; then
    echo '{ "present": false, "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

POWER=$(LC_ALL=C nmcli radio wifi)

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "present": true, "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

CACHE_DIR="$QS_CACHE_NETWORK"
mkdir -p "$CACHE_DIR"

CURRENT_RAW=$(LC_ALL=C nmcli -t -f active,ssid,signal,security device wifi | awk -F: '$1=="yes"{print; exit}')

if [[ -n "$CURRENT_RAW" ]]; then
    IFS=':' read -r active ssid signal security <<< "$CURRENT_RAW"
    icon=$(get_icon "$signal")
    
    SAFE_SSID="${ssid//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"
    
    IP=""
    FREQ=""
    if [ -f "$CACHE_FILE" ]; then
        IP=$(awk -F= '$1=="IP"{print substr($0,4)}' "$CACHE_FILE" 2>/dev/null)
        FREQ=$(awk -F= '$1=="FREQ"{print substr($0,6)}' "$CACHE_FILE" 2>/dev/null)
    fi
    
    IP="${IP//\"/}"
    FREQ="${FREQ//\"/}"

    if [ -z "$IP" ] || [ "$IP" == "No IP" ] || [ -z "$FREQ" ]; then
        IFACE=$(LC_ALL=C nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1;exit}')
        IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        [ -z "$IP" ] && IP="No IP"
        
        FREQ=$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/ {print $2}')
        [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"
        
        IP="${IP//\"/}"
        FREQ="${FREQ//\"/}"
        printf "IP=%s\nFREQ=%s\n" "$IP" "$FREQ" > "$CACHE_FILE"
    fi

    CONNECTED_JSON=$(jq -nc \
        --arg id "$ssid" \
        --arg ssid "$ssid" \
        --arg icon "$icon" \
        --arg signal "$signal" \
        --arg security "$security" \
        --arg ip "$IP" \
        --arg freq "$FREQ" \
        '{id: $id, ssid: $ssid, icon: $icon, signal: $signal, security: $security, ip: $ip, freq: $freq}')
else
    ssid=""
    CONNECTED_JSON="null"
fi

# AWK processes the entire network list natively, zero sub-shells
# Reverted back to SSID-only deduplication, but passing conn="$ssid" to cleanly exclude the connected network
NETWORKS_JSON=$(LC_ALL=C nmcli -t -f active,ssid,signal,security device wifi list --rescan no | awk -F: -v conn="$ssid" '
    $2 != "" && $2 != conn && !seen[$2]++ {
        ssid=$2; signal=$3; security=$4;
        
        # Escape quotes inside strings
        gsub(/"/, "\\\"", ssid);
        gsub(/"/, "\\\"", security);
        
        if (signal >= 80) icon="󰤨";
        else if (signal >= 60) icon="󰤥";
        else if (signal >= 40) icon="󰤢";
        else if (signal >= 20) icon="󰤟";
        else icon="󰤯";
        
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\"}\n", ssid, ssid, icon, signal, security
    }
' | head -n 24 | paste -sd, -)

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

# Ensure NETWORKS_JSON is valid JSON
if ! echo "$NETWORKS_JSON" | jq -e . >/dev/null 2>&1; then
    NETWORKS_JSON="[]"
fi

# Final JSON output via jq
jq -nc \
    --argjson connected "$CONNECTED_JSON" \
    --argjson networks "$NETWORKS_JSON" \
    '{present: true, power: "on", connected: $connected, networks: $networks}'
