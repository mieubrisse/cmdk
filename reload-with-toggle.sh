#!/usr/bin/env bash

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

# Get current toggle state
toggle_state="$(bash "${script_dirpath}/actions/toggle-state.sh" get)"

# Build arguments for list-files.sh
args=""
if [ "$toggle_state" = "on" ]; then
    args="-e"
fi

# Add original arguments passed to cmdk
for arg in "$@"; do
    args="$args $arg"
done

# Execute list-files.sh with appropriate flags
# shellcheck disable=SC2086
bash "${script_dirpath}/list-files.sh" $args