#!/usr/bin/env bash

# Fetch all changed files from git (modified, staged, untracked)
# Returns deduplicated list of file paths

set -euo pipefail

# Check if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 1
fi

# Fetch files from git, exit silently if git commands fail
modified=$(git diff --name-only 2>/dev/null) || true
staged=$(git diff --cached --name-only 2>/dev/null) || true
untracked=$(git ls-files --others --exclude-standard 2>/dev/null) || true

# Combine and deduplicate
(
    echo "$modified"
    echo "$staged"
    echo "$untracked"
) | sort -u | grep -v '^$' || true
