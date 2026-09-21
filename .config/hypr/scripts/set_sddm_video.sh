#!/usr/bin/env bash

THEME_DIR="/usr/share/sddm/themes/silent"
DEST_DIR="$THEME_DIR/backgrounds"

# Get all current mp4/mkv files in the backgrounds directory
AVAILABLE_VIDEOS=$(ls -1 "$DEST_DIR" | grep -E "\.(mp4|mkv|webm)$")

# Build zenity list arguments
LIST_ARGS=()
for v in $AVAILABLE_VIDEOS; do
    LIST_ARGS+=("$v" "")
done
LIST_ARGS+=("+ Add Custom Video..." "")

CHOICE=$(zenity --list --title="SDDM Video Selection" --text="Select a login screen video or add a new one:" --column="Video" --column="Status" --hide-column=2 --print-column=1 "${LIST_ARGS[@]}" 2>/dev/null)

if [ -z "$CHOICE" ]; then
    exit 0
fi

if [ "$CHOICE" == "+ Add Custom Video..." ]; then
    VIDEO_FILE=$(zenity --file-selection --title="Select a Video for SDDM" --file-filter="Video files | *.mp4 *.mkv *.webm" 2>/dev/null)
    if [ -z "$VIDEO_FILE" ]; then exit 0; fi
    BASENAME=$(basename "$VIDEO_FILE")
    
    # Copy new video with pkexec
    pkexec bash -c "cp \"$VIDEO_FILE\" \"$DEST_DIR/$BASENAME\" && chmod 644 \"$DEST_DIR/$BASENAME\""
    if [ $? -ne 0 ]; then
        zenity --error --text="Failed to copy video. Permission denied."
        exit 1
    fi
    TARGET_VIDEO="$BASENAME"
else
    TARGET_VIDEO="$CHOICE"
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
    zenity --info --text="Successfully set SDDM background to $TARGET_VIDEO!"
else
    zenity --error --text="Failed to update SDDM config."
fi
