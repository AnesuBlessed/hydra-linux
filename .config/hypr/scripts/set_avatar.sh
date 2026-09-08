#!/usr/bin/env bash

# ==============================================================================
# set_avatar.sh - Select and update user avatar for Hydra Linux
# ==============================================================================

TARGET_IMG="$1"

if [ -z "$TARGET_IMG" ]; then
    if command -v zenity &>/dev/null; then
        TARGET_IMG=$(zenity --file-selection --title="Select Profile Avatar" --file-filter="Images (png, jpg, webp) | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP" 2>/dev/null)
    elif command -v kdialog &>/dev/null; then
        TARGET_IMG=$(kdialog --getopenfilename "$HOME/Pictures" "*.png *.jpg *.jpeg *.webp | Image Files" 2>/dev/null)
    fi
fi

if [ -z "$TARGET_IMG" ] || [ ! -f "$TARGET_IMG" ]; then
    exit 0
fi

TMP_AVATAR="/tmp/hydra_avatar_${USER}.png"

# Center crop 1:1 square and resize to 512x512
if command -v magick &>/dev/null; then
    magick "$TARGET_IMG" -gravity center -crop 1:1 +repage -resize 512x512 "$TMP_AVATAR"
elif command -v convert &>/dev/null; then
    convert "$TARGET_IMG" -gravity center -crop 1:1 +repage -resize 512x512 "$TMP_AVATAR"
else
    cp "$TARGET_IMG" "$TMP_AVATAR"
fi

# Deploy to user home
cp -f "$TMP_AVATAR" "$HOME/.face.icon"
cp -f "$TMP_AVATAR" "$HOME/.face"

# Deploy to SDDM faces if writable
SDDM_FACE="/usr/share/sddm/faces/${USER}.face.icon"
if [ -w "$SDDM_FACE" ] || [ -w "/usr/share/sddm/faces" ]; then
    cp -f "$TMP_AVATAR" "$SDDM_FACE" 2>/dev/null || true
fi

# Clear Quickshell info cache so the UI refreshes
rm -f "$HOME/.cache/guide/sysinfo.txt" 2>/dev/null || true
rm -rf "/run/user/${UID}/quickshell/cache/guide" 2>/dev/null || true

# Send desktop notification with avatar preview
notify-send -a "Hydra Linux" -i "$HOME/.face.icon" "Avatar Updated" "Profile picture has been successfully updated!" 2>/dev/null || true

echo "$HOME/.face.icon"
