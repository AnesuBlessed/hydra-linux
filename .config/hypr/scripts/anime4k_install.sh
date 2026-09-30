#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_SHADERS="$SCRIPT_DIR/../../mpv/shaders"

mkdir -p "$HOME/.config/mpv/shaders"

# Copy from bundled repository shaders if available
if [ -d "$REPO_SHADERS" ]; then
    cp -rn "$REPO_SHADERS/"* "$HOME/.config/mpv/shaders/" 2>/dev/null || true
fi

# Ensure input.conf has Anime4K keybinds without destructively wiping existing settings
mkdir -p "$HOME/.config/mpv"
if [ ! -f "$HOME/.config/mpv/input.conf" ] || ! grep -q "Anime4K" "$HOME/.config/mpv/input.conf" 2>/dev/null; then
    cat << 'MPVCONF' >> "$HOME/.config/mpv/input.conf"
Ctrl+1 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A (Fast)"
Ctrl+2 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_VL.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode A (HQ)"
Ctrl+0 no-osd change-list glsl-shaders clr ""; show-text "Anime4K: Disabled"
MPVCONF
fi
