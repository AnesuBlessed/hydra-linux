#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CACHING & MIGRATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

RAW_MONITOR="${1:-global}"
exec python3 "$(dirname "${BASH_SOURCE[0]}")/workspaces.py" "$RAW_MONITOR"
