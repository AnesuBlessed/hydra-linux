#!/usr/bin/env bash
#
# Print up to five directories matching a path prefix, for the settings path box.
#
# The prefix is handled as data — expanded with the shell's own globbing, never
# passed through eval — so typed text cannot become a command.
#
# Usage: path_suggest.sh <prefix>

set -uo pipefail

query=${1-}
[[ -n "$query" ]] || exit 0

# Expand a leading ~ ourselves; tilde expansion does not apply to variables.
# shellcheck disable=SC2088  # matching a literal tilde in the user's input
if [[ "$query" == "~" || "$query" == "~/"* ]]; then
    query="$HOME${query:1}"
fi

shopt -s nullglob
matches=("$query"*/)
(( ${#matches[@]} )) || exit 0

printf '%s\n' "${matches[@]:0:5}"
