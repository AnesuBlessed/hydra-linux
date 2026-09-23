#!/usr/bin/env bash
#
# Print the installed Hydra version.
#
# The state file is parsed as data — never sourced — so a corrupt or tampered
# state file cannot execute code in the user's session.
#
# Usage: hydra_version.sh [fallback]   (fallback defaults to 1.0.0)

set -euo pipefail

for state in "$HOME/.local/state/hydra-linux-version" \
             "$HOME/.local/state/imperative-dots-version"; do
    [[ -r "$state" ]] || continue
    version=$(sed -n \
        's/^[[:space:]]*LOCAL_VERSION[[:space:]]*=[[:space:]]*"\{0,1\}\([0-9A-Za-z._+-]\{1,\}\)"\{0,1\}[[:space:]]*$/\1/p' \
        "$state" | head -n 1)
    if [[ -n "$version" ]]; then
        printf '%s\n' "$version"
        exit 0
    fi
done

printf '%s\n' "${1:-1.0.0}"
