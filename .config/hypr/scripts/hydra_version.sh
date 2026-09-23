#!/usr/bin/env bash
# ==============================================================================
# hydra_version.sh - Safely read Hydra Linux version without sourcing state files
# ==============================================================================

read_version() {
    local file="$1"
    if [[ -r "$file" ]]; then
        # Parse LOCAL_VERSION="X.Y.Z" or bare version string safely
        local val
        val=$(awk -F= '/^LOCAL_VERSION=/ { gsub(/["'\'']/, "", $2); print $2; exit }' "$file" 2>/dev/null)
        if [[ -n "$val" ]]; then
            echo "$val"
            return 0
        fi
        # If no key=value found, check if line 1 looks like a version
        val=$(head -n 1 "$file" | tr -d '\r\n')
        if [[ "$val" =~ ^[0-9]+\.[0-9]+ ]]; then
            echo "$val"
            return 0
        fi
    fi
    return 1
}

# 1. Check user state files
for state_path in "$HOME/.local/state/hydra-linux-version" \
                  "$HOME/.local/state/imperative-dots-version"; do
    if ver=$(read_version "$state_path"); then
        echo "$ver"
        exit 0
    fi
done

# 2. Check repo version.txt fallback if state file is missing
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
for repo_ver in "$SCRIPT_DIR/../../version.txt" \
                "$SCRIPT_DIR/../../../version.txt"; do
    if [[ -r "$repo_ver" ]]; then
        ver=$(head -n 1 "$repo_ver" | tr -d '\r\n')
        if [[ -n "$ver" ]]; then
            echo "$ver"
            exit 0
        fi
    fi
done

echo "1.0.2"
