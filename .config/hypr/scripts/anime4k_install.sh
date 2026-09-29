#!/bin/bash
mkdir -p ~/.config/mpv/shaders
wget -qO ~/.config/mpv/shaders/Anime4K_Clamp_Highlights.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_Clamp_Highlights.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_Restore_CNN_M.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_Restore_CNN_M.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_Upscale_CNN_x2_M.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_Upscale_CNN_x2_M.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_Restore_CNN_S.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_Restore_CNN_S.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_AutoDownscalePre_x2.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_AutoDownscalePre_x2.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_AutoDownscalePre_x4.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_AutoDownscalePre_x4.glsl"
wget -qO ~/.config/mpv/shaders/Anime4K_Upscale_CNN_x2_S.glsl "https://raw.githubusercontent.com/bloc97/Anime4K/master/glsl/Anime4K_Upscale_CNN_x2_S.glsl"
cat << 'MPVCONF' > ~/.config/mpv/input.conf
Ctrl+1 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A (Fast)"
Ctrl+2 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_VL.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode A (HQ)"
Ctrl+0 no-osd change-list glsl-shaders clr ""; show-text "Anime4K: Disabled"
MPVCONF
