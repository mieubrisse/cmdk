#!/usr/bin/env bash

# Manage git filter toggle state (same pattern as toggle-state.sh)

set -euo pipefail

STATE_FILE="/tmp/cmdk_git_toggle_${USER}"

case "${1:-}" in
    "get")
        if [ -f "$STATE_FILE" ]; then
            cat "$STATE_FILE"
        else
            echo "off"
        fi
        ;;
    "toggle")
        if [ -f "$STATE_FILE" ]; then
            current_state="$(cat "$STATE_FILE")"
        else
            current_state="off"
        fi
        if [ "$current_state" = "on" ]; then
            echo "off" > "$STATE_FILE"
            echo "off"
        else
            echo "on" > "$STATE_FILE"
            echo "on"
        fi
        ;;
    "init")
        # Initialize with given state or default to off
        state="${2:-off}"
        echo "$state" > "$STATE_FILE"
        echo "$state"
        ;;
    "cleanup")
        rm -f "$STATE_FILE"
        ;;
    *)
        echo "Usage: $0 {get|toggle|init [on|off]|cleanup}" >&2
        exit 1
        ;;
esac
