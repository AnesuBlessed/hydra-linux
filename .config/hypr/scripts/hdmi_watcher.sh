#!/usr/bin/env bash
# ==============================================================================
# 📺 AUTOMATIC HDMI HOTPLUG, AUDIO & WALLPAPER SWITCHER FOR HYPRLAND
# ==============================================================================

# Ensure only one instance of hdmi_watcher.sh runs
for pid in $(pidof -x hdmi_watcher.sh 2>/dev/null); do
    if [ "$pid" != "$$" ]; then
        kill "$pid" 2>/dev/null || true
    fi
done

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
CARD="alsa_card.pci-0000_00_1f.3"
LAST_EVENT_TIME=0

sync_wallpaper() {
    local wp
    wp=$(awww query 2>/dev/null | grep "eDP-1" | grep -o '/home/[^ ]*' | head -n 1)
    if [ -n "$wp" ] && [ -f "$wp" ]; then
        awww img -o HDMI-A-1 "$wp" --transition-type simple 2>/dev/null || true
    fi
}

switch_audio_to_hdmi() {
    # Retry up to 5 times (with 300ms backoff) to ensure ALSA DRM endpoint is ready
    for i in {1..5}; do
        if pactl set-card-profile "$CARD" output:hdmi-stereo+input:analog-stereo >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.3
    done
}

switch_audio_to_laptop() {
    pactl set-card-profile "$CARD" output:analog-stereo+input:analog-stereo >/dev/null 2>&1 || true
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
    amixer -c 0 set Master unmute >/dev/null 2>&1 || true
    amixer -c 0 set Speaker unmute >/dev/null 2>&1 || true
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
    
    case "$event" in
        monitoradded*HDMI*|monitoradded*DP*)
            # 1. Switch sound to HDMI TV / DisplayPort output with retry
            (switch_audio_to_hdmi) &
            
            # 2. Sync wallpaper to the new screen
            (sleep 0.5 && sync_wallpaper) &
            
            # 3. Desktop notification
            notify-send -i video-display "HDMI Connected" "Display enabled, wallpaper synced & sound routed to TV"
            ;;
        monitorremoved*HDMI*|monitorremoved*DP*)
            # Switch sound back to laptop internal speakers
            switch_audio_to_laptop
            notify-send -i audio-speakers "HDMI Disconnected" "Sound returned to laptop speakers"
            ;;
    esac
}

# Initial check on startup if external HDMI or DP is already connected
if hyprctl monitors | grep -E '^Monitor ' | grep -v -q 'eDP'; then
    switch_audio_to_hdmi &
    sync_wallpaper &
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
