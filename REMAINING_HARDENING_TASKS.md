# Remaining Hydra hardening tasks

This file tracks the remaining work to apply based on the hardening changes discussed, while keeping Lua and media files untouched.

## Scope
- Leave all Lua files alone
- Leave all media assets, wallpapers, and SDDM videos alone
- Only patch shell and runtime-script hardening items

## Pending items

### 1) Safe version lookup
- Create: `.config/hypr/scripts/hydra_version.sh`
- Purpose: read the Hydra version from the user state file without sourcing it
- Must avoid executing arbitrary content from `~/.local/state/*`

### 2) Lock script hardening
- File: `.config/hypr/scripts/lock.sh`
- Change: scope `pgrep` to the current user only
- Replace global process detection with user-scoped detection

### 3) Pocket watcher runtime-state hardening
- File: `.config/hypr/scripts/pocket_watcher.sh`
- Change: move its state file into `QS_RUN_DIR` instead of `/tmp`
- Fix unsafe array mutation patterns like `unset new_state[$addr]`
- Use `source caching.sh` if not already sourced

### 4) Wallpaper search runtime hardening
- File: `.config/hypr/scripts/quickshell/wallpaper/get_ddg_links.py`
- Change: store runtime directories under `XDG_RUNTIME_DIR` / `quickshell`
- Remove reliance on shared `/tmp/quickshell` paths

### 5) Weather script env parsing hardening
- File: `.config/hypr/scripts/quickshell/calendar/weather.sh`
- Change: replace unsafe `export $(grep ...)` logic with a safe line-by-line parser
- Keep the same runtime behavior

### 6) Watcher script shell hygiene
- Files:
  - `.config/hypr/scripts/quickshell/watchers/audio_fetch.sh`
  - `.config/hypr/scripts/quickshell/watchers/battery_fetch.sh`
- Change: avoid unsafe local assignment patterns and keep shell compatibility

### 7) HDMI watcher safety cleanup
- File: `.config/hypr/scripts/hdmi_watcher.sh`
- Change: fix shell loop-variable usage without changing functionality or media behavior

### 8) Quickshell manager runtime/process hardening
- File: `.config/hypr/scripts/qs_manager.sh`
- Change: apply user-scoped `pgrep` checks
- Use runtime-scoped environment variables instead of hard-coded shared paths
- Preserve the same reload / shell startup behavior

### 9) Caching script review and retention
- File: `.config/hypr/scripts/caching.sh`
- Action: keep the user-scoped runtime/cache/state directory design in place
- This file is already aligned with the requested hardening pattern and should remain untouched unless a bug is found

## Status
Pending final repo application.

This is the list of changes still to be applied according to the hardening plan discussed, without touching Lua or media files.
