#!/usr/bin/env bash
#
# Set the Silent SDDM login background video.
#
# Privileged work runs through pkexec with the untrusted values passed as
# positional parameters, never interpolated into the program text.

set -Eeuo pipefail

THEME_DIR="/usr/share/sddm/themes/silent"
DEST_DIR="$THEME_DIR/backgrounds"

# Direct file selection starting in the backgrounds folder
VIDEO_FILE=$(zenity --file-selection \
    --title="Select a Video for SDDM" \
    --filename="$DEST_DIR/" \
    --file-filter="Video files | *.mp4 *.mkv *.webm" 2>/dev/null)

if [ -z "$VIDEO_FILE" ]; then exit 0; fi
if [ ! -f "$VIDEO_FILE" ]; then exit 0; fi

BASENAME=$(basename -- "$VIDEO_FILE")
TARGET_VIDEO="$BASENAME"

# The name ends up quoted inside the theme config, so refuse the characters
# that would break out of that quoting.
if [[ "$BASENAME" == *['"'\\]* || "$BASENAME" == -* ]]; then
    zenity --error --text="Unsupported file name: $BASENAME"
    exit 1
fi

# Check if the chosen file is already in the DEST_DIR.
# If it's a new custom file from somewhere else, copy it over.
if [[ "$VIDEO_FILE" != "$DEST_DIR/$BASENAME" ]]; then
    if ! pkexec install -o root -g root -m 644 -T -- "$VIDEO_FILE" "$DEST_DIR/$BASENAME"; then
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

# Update the background line in the active SDDM config. The script body below is
# a fixed literal; the config path and video name arrive as "$1" and "$2".
# shellcheck disable=SC2016  # positional parameters are for the nested shell
if pkexec bash -c '
    set -Eeuo pipefail
    conf=$1
    video=$2
    tmp=$(mktemp)
    trap '\''rm -f "$tmp"'\'' EXIT
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ ^([[:space:]]*)background[[:space:]]*=[[:space:]]*\".*\"[[:space:]]*$ ]]; then
            printf "%sbackground = \"%s\"\n" "${BASH_REMATCH[1]}" "$video"
        else
            printf "%s\n" "$line"
        fi
    done <"$conf" >"$tmp"
    cat "$tmp" >"$conf"
' hydra-set-sddm-video "$CONF_PATH" "$TARGET_VIDEO"; then
    notify-send -a "Hydra Linux" -i "video-x-generic" "SDDM Video Updated" "Login video successfully set to $TARGET_VIDEO" 2>/dev/null || true
else
    zenity --error --text="Failed to update SDDM config."
fi
