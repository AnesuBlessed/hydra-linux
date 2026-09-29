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
# If it's a new custom file from somewhere else, copy it over securely using install
if [[ "$VIDEO_FILE" != "$DEST_DIR/$BASENAME" ]]; then
    if ! pkexec install -m 644 -- "$VIDEO_FILE" "$DEST_DIR/$BASENAME"; then
        zenity --error --text="Failed to copy video. Permission denied."
        exit 1
    fi
fi

ACTIVE_CONF=$(awk -F= '/^ConfigFile=/ { print $2; exit }' "$THEME_DIR/metadata.desktop" 2>/dev/null)

if [ -z "$ACTIVE_CONF" ]; then
    zenity --error --text="Could not determine the active SDDM config."
    exit 1
fi

CONF_PATH="$THEME_DIR/$ACTIVE_CONF"

# Update the background line in the active SDDM config safely using arguments
if pkexec bash -c '
    target_vid="$1"
    conf_file="$2"
    if [[ -f "$conf_file" ]]; then
        escaped_vid=$(printf "%s" "$target_vid" | sed "s/[&/\]/\\&/g")
        sed -i -E "s/^([[:space:]]*background[[:space:]]*=[[:space:]]*\")[^\"]*(\".*)$/\1$escaped_vid\2/" "$conf_file"
    else
        exit 1
    fi
' _ "$TARGET_VIDEO" "$CONF_PATH"; then
    notify-send -a "Hydra Linux" -i "video-x-generic" "SDDM Video Updated" "Login video successfully set to $TARGET_VIDEO" 2>/dev/null || true
else
    zenity --error --text="Failed to update SDDM config."
fi
