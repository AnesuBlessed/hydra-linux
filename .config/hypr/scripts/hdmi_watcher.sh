#!/usr/bin/env bash
# ==============================================================================
# 📺 AUTOMATIC HDMI/DP HOTPLUG, AUDIO & WALLPAPER SWITCHER FOR HYPRLAND
# ==============================================================================

# Ensure only one instance of hdmi_watcher.sh runs for the current user
for pid in $(pgrep -u "$UID" -f "hdmi_watcher\.sh" 2>/dev/null); do
    if [ "$pid" != "$$" ]; then
        kill "$pid" 2>/dev/null || true
    fi
done

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
LAST_EVENT_TIME=0

sync_wallpaper() {
    local target_mon="$1"
    local wp
    # Get current wallpaper path from any running monitor
    wp=$(awww query 2>/dev/null | grep -o '/[^ ]*' | head -n 1)
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        if [ -n "$target_mon" ]; then
            awww img -o "$target_mon" "$wp" --transition-type simple 2>/dev/null || true
        else
            awww img "$wp" --transition-type simple 2>/dev/null || true
        fi
    fi
}

switch_audio_to_hdmi() {
    local card
    card=$(pactl list cards short 2>/dev/null | awk '{print $2}' | grep -E '^alsa_card\.' | head -n 1)
    if [ -n "$card" ]; then
        for i in {1..5}; do
            local prof
            prof=$(pactl list cards 2>/dev/null | awk -v c="$card" '$0 ~ c { found=1 } found && /output:hdmi.*stereo.*input:analog/ { gsub(/^[ \t]+|:.*$/, ""); print; exit }')
            [ -z "$prof" ] && prof="output:hdmi-stereo+input:analog-stereo"
            if pactl set-card-profile "$card" "$prof" >/dev/null 2>&1; then
                break
            fi
            sleep 0.3
        done
    fi

    # Set default sink to HDMI/DP if available
    local hdmi_sink
    hdmi_sink=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -iE 'hdmi|displayport' | head -n 1)
    if [ -n "$hdmi_sink" ]; then
        pactl set-default-sink "$hdmi_sink" 2>/dev/null || true
    fi
}

switch_audio_to_laptop() {
    local card
    card=$(pactl list cards short 2>/dev/null | awk '{print $2}' | grep -E '^alsa_card\.' | head -n 1)
    if [ -n "$card" ]; then
        local prof
        prof=$(pactl list cards 2>/dev/null | awk -v c="$card" '$0 ~ c { found=1 } found && /output:analog-stereo\+input:analog-stereo/ { gsub(/^[ \t]+|:.*$/, ""); print; exit }')
        [ -z "$prof" ] && prof="output:analog-stereo+input:analog-stereo"
        pactl set-card-profile "$card" "$prof" >/dev/null 2>&1 || true
    fi

    local analog_sink
    analog_sink=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -v -iE 'hdmi|displayport' | head -n 1)
    if [ -n "$analog_sink" ]; then
        pactl set-default-sink "$analog_sink" 2>/dev/null || true
    fi

    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
    amixer set Master unmute >/dev/null 2>&1 || true
    amixer set Speaker unmute >/dev/null 2>&1 || true
}

handle_event() {
    local event="$1"
    local now
    now=$(date +%s)
    
    # Ignore internal laptop display events completely
    case "$event" in
        *eDP*)
            return
            ;;
    esac

    # 1-second debounce to prevent duplicate pin contact triggers
    if (( now - LAST_EVENT_TIME < 1 )); then
        return
    fi
    LAST_EVENT_TIME=$now

    local ev_type="${event%%>>*}"
    local mon_name="${event#*>>}"
    
    case "$ev_type" in
        monitoradded)
            # 1. Switch sound to HDMI TV / DisplayPort output with retry
            (switch_audio_to_hdmi) &
            
            # 2. Sync wallpaper to the new screen
            (sleep 0.5 && sync_wallpaper "$mon_name") &
            
            # 3. Desktop notification
            notify-send -i video-display "Display Connected" "Display ($mon_name) enabled, wallpaper synced & sound routed"
            ;;
        monitorremoved)
            # Switch sound back to laptop internal speakers
            switch_audio_to_laptop
            notify-send -i audio-speakers "Display Disconnected" "Display ($mon_name) removed. Sound returned to internal speakers"
            ;;
    esac
}

# Initial check on startup if external HDMI or DP is already connected
if hyprctl monitors 2>/dev/null | awk '/^Monitor / { if ($2 !~ /^eDP/) print $2 }' | grep -q .; then
    switch_audio_to_hdmi &
    for mon in $(hyprctl monitors 2>/dev/null | awk '/^Monitor / { if ($2 !~ /^eDP/) print $2 }'); do
        sync_wallpaper "$mon" &
    done
else
    # Otherwise ensure laptop audio is properly configured
    switch_audio_to_laptop &
fi

# Listen to live Hyprland event socket
if [ -S "$SOCKET" ]; then
    socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
        handle_event "$line"
    done
fi
