#!/usr/bin/env bash

# Unified reload script handling both .env visibility and git filter toggles
# Usage: reload-files.sh [cmdk args]
#
# Features:
#   - Ctrl+T: Toggle .env/.gitignored file visibility
#   - Ctrl+G: Toggle between all files and git-changed files only
#   - Toggles work independently and can be combined

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

# Check git filter state
git_filter_state=$(bash "${script_dirpath}/actions/git-toggle-state.sh" get)

if [ "$git_filter_state" = "on" ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        bash "${script_dirpath}/git-files.sh" 2>/dev/null
    else
        bash "${script_dirpath}/reload-with-toggle.sh" "$@"
    fi
else
    # Show normal file list (respects .env toggle via reload-with-toggle.sh)
    bash "${script_dirpath}/reload-with-toggle.sh" "$@"
fi
