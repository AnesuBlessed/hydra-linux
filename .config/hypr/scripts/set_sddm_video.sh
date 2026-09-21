#!/usr/bin/env bash

THEME_DIR="/usr/share/sddm/themes/silent"
DEST_DIR="$THEME_DIR/backgrounds"

# Direct file selection starting in the backgrounds folder
VIDEO_FILE=$(zenity --file-selection \
    --title="Select a Video for SDDM" \
    --filename="$DEST_DIR/" \
    --file-filter="Video files | *.mp4 *.mkv *.webm" 2>/dev/null)

if [ -z "$VIDEO_FILE" ]; then exit 0; fi
if [ ! -f "$VIDEO_FILE" ]; then exit 0; fi

BASENAME=$(basename "$VIDEO_FILE")
TARGET_VIDEO="$BASENAME"

# Check if the chosen file is already in the DEST_DIR.
# If it's a new custom file from somewhere else, copy it over.
if [[ "$VIDEO_FILE" != "$DEST_DIR/$BASENAME" ]]; then
    pkexec bash -c "cp \"$VIDEO_FILE\" \"$DEST_DIR/$BASENAME\" && chmod 644 \"$DEST_DIR/$BASENAME\""
    if [ $? -ne 0 ]; then
        zenity --error --text="Failed to copy video. Permission denied."
        exit 1
    fi
fi

ACTIVE_CONF=$(grep "^ConfigFile=" "$THEME_DIR/metadata.desktop" | cut -d'=' -f2 | head -n 1)

if [ -z "$ACTIVE_CONF" ]; then
    zenity --error --text="Could not determine the active SDDM config."
    exit 1
fi

CONF_PATH="$THEME_DIR/$ACTIVE_CONF"

# Update the background line in the active SDDM config
pkexec bash -c "sed -i 's/background = \".*\"/background = \"$TARGET_VIDEO\"/g' \"$CONF_PATH\""

if [ $? -eq 0 ]; then
    notify-send -a "Hydra Linux" -i "video-x-generic" "SDDM Video Updated" "Login video successfully set to $TARGET_VIDEO" 2>/dev/null || true
else
    zenity --error --text="Failed to update SDDM config."
fi
