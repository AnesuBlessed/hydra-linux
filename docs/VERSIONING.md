# Hydra Linux 1.0.2

Hydra Linux is a complete Hyprland desktop environment built around Quickshell, Matugen dynamic theming, and the Silent SDDM greeter.

## Current version

The repository has one current version: **1.0.2**.

The canonical version is stored in [`version.txt`](../version.txt). Update metadata in [`updates.json`](../updates.json) intentionally contains only the current release entry so the updater cannot advertise stale versions.

## What changed in 1.0.2

- Hardened update-version reading so local state is treated as data rather than executable shell code.
- Moved Quickshell runtime files away from shared `/tmp` paths and into private user-owned runtime/cache directories.
- Preserved the native Lua Hyprland configuration and all repository media.
- Began consolidating security and maintenance improvements from the repository review.

## Versioning policy

Hydra Linux uses semantic versions in the form `MAJOR.MINOR.PATCH`:

- **MAJOR**: incompatible architecture or installation changes.
- **MINOR**: backwards-compatible features.
- **PATCH**: fixes, hardening, documentation, and maintenance.

For a release, update `version.txt`, replace the single object in `updates.json`, and create a matching Git tag such as `v1.0.2`. Do not keep obsolete release entries in `updates.json`.

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
