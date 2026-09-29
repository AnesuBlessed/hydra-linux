# Hydra Linux 1.0.0

Hydra Linux is a complete Hyprland desktop environment built around Quickshell, Matugen dynamic theming, and the Silent SDDM greeter.

## Current version

The repository has one current version: **1.0.0**.

The canonical version is stored in [`version.txt`](../version.txt). Update metadata in [`updates.json`](../updates.json) intentionally contains only the current release entry so the updater cannot advertise stale versions.

## What changed in 1.0.0

This is the first complete release. It supersedes the 1.0.x development line, whose history has been squashed into this single commit. The substantive work:

### Scaling and responsiveness

- Scaling is now output-scale aware. `WindowRegistry.js` samples the compositor's real output scale and applies it damped and clamped, so the bar reads the same physical size on a HiDPI laptop as on a standard monitor. Non-HiDPI displays are unchanged.
- `Scaler` receives a real height at every call site. Previously the default assumed 1080p, so popups under-scaled on taller screens and disagreed with the window size reserved for them.
- The top bar has a genuine layout cascade. `densityTier` is measured in logical pixels (independent of both resolution and `uiScale`) and sheds media text, then network labels, then the tray and media box as space runs out. Thresholds are derived from the measured content budget, not guessed.
- The workspace highlight derives its geometry from the real delegate positions and clamps to the visible pill count, so it no longer drifts or lands on hidden slots.

### Multi-monitor

- One workspace daemon per output, coordinated with `flock` and writing per-monitor state files. The previous `pgrep`-and-kill approach made every new instance murder the others, which froze the workspace bar on all but the last monitor.
- Each monitor now resolves its own active workspace instead of sharing the focused monitor's index.

### Resource lifecycle

- Popup pollers and infinite animations are gated on real visibility. The previous gating was a no-op because nothing ever set the popups' root `visible`; `Main` now owns that state.
- A single settings singleton replaces four independent `cat` + `inotifywait` pairs reading the same file.
- Pollers wait for in-flight work instead of killing it mid-run, which had been truncating samples and freezing panels on stale values.
- The lock screen no longer retries PAM on a 50 ms loop without backoff or a cap.

### Correctness and security

- Command injection removed from SSID, Bluetooth device, avatar, and clipboard paths. All now use argument arrays.
- Runtime and cache paths no longer diverge between the QML and shell implementations, and no longer fall back to a world-readable shared `/tmp`.
- Atomic writes with locking, so concurrent settings saves can no longer lose each other.
- Notification sorting no longer mutates the model while iterating it, which was destroying entries.
- The installer no longer writes world-writable configuration to the login greeter, and ships an interactive selector with arrow-key and space navigation.

### Repository

- CI runs QML, shell, Python, and hygiene checks on every push.
- Guide previews resized and converted to WebP: 20 MB to 1.3 MB.
- No personal paths, dead config files, or build artifacts are committed.

## Versioning policy

Hydra Linux uses semantic versions in the form `MAJOR.MINOR.PATCH`:

- **MAJOR**: incompatible architecture or installation changes.
- **MINOR**: backwards-compatible features.
- **PATCH**: fixes, hardening, documentation, and maintenance.

For a release, update `version.txt`, replace the single object in `updates.json`, and create a matching Git tag such as `v1.0.0`. Do not keep obsolete release entries in `updates.json`.

## Installation

Hydra Linux targets Arch Linux and Arch-based distributions. From a clean checkout:

```bash
git clone https://github.com/AnesuBlessed/hydra-linux.git
cd hydra-linux
chmod +x install.sh
./install.sh
```

See [`README.md`](../README.md) for the full feature list, dependencies, installer options, keybindings, SDDM setup, and troubleshooting guidance.

## Repository preservation rules

The Lua configuration under `.config/hypr/` and the bundled media under `wallpapers/` and the Silent SDDM theme are intentional project assets. Cleanup must not remove or replace them merely to reduce repository size.

## License

Hydra Linux is licensed under the [GNU General Public License v3.0](../LICENSE).
