#!/usr/bin/env bash
# Trigger session lock
loginctl lock-session

# Wait for quickshell lock screen to acquire the session lock
# We wait up to 3 seconds for the lock screen to spawn
for i in {1..30}; do
    if pgrep -f "quickshell.*Lock.qml" >/dev/null 2>&1; then
        sleep 0.5 # Give it a moment to actually render and grab the DRM lease
        break
    fi
    sleep 0.1
done

# Suspend the system
systemctl suspend
