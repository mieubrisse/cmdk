#!/usr/bin/env bash

# This is the core of cmdk, written in Bash.
# The entrypoint cmdk.sh and cmdk.fish call down to this
#
# Rationale: I didn't want to rewrite the entire thing to be zsh-
# and fish-compatible :S

set -euo pipefail

for cmd in fzf fd file; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Error: '${cmd}' is required but not found. Please install it first." >&2
        exit 1
    fi
done

script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

validated_flags=()
while [ $# -gt 0 ]; do
    case "$1" in
        -o|-s|-e)
            validated_flags+=("$1")
            shift
            ;;
        *)
            echo "Error: Unknown flag '$1'. Allowed flags: -o, -s, -e" >&2
            exit 1
            ;;
    esac
done

flags_str="${validated_flags[*]:-}"

output_paths=()

# Initialize toggle states based on -e flag
if echo "${flags_str}" | grep -q '\-e'; then
    bash "${script_dirpath}/actions/toggle-state.sh" init on >/dev/null
else
    bash "${script_dirpath}/actions/toggle-state.sh" init off >/dev/null
fi
bash "${script_dirpath}/actions/git-toggle-state.sh" init off >/dev/null

# Use a temporary file instead of process substitution for better shell compatibility
temp_output_file="$(mktemp)"

cleanup() {
    rm -f "${temp_output_file}"
    bash "${script_dirpath}/actions/toggle-state.sh" cleanup >/dev/null 2>&1 || true
    bash "${script_dirpath}/actions/git-toggle-state.sh" cleanup >/dev/null 2>&1 || true
}
trap cleanup EXIT

# EXPLANATION:
# -m allows multiple selections
# --ansi tells fzf to parse the ANSI color codes that we're generating with fd
# --scheme=path optimizes for path-based input
# --with-nth allows us to use the custom sorting mechanism
# --bind='ctrl-i:...' adds Ctrl+I to toggle .env visibility
FZF_DEFAULT_COMMAND="bash ${script_dirpath}/reload-files.sh ${flags_str}" fzf \
    -m \
    --ansi \
    --bind='change:top' \
    --bind="ctrl-t:reload(bash ${script_dirpath}/actions/toggle-state.sh toggle >/dev/null && bash ${script_dirpath}/reload-files.sh ${flags_str})" \
    --bind="ctrl-g:reload(bash ${script_dirpath}/actions/git-toggle-state.sh toggle >/dev/null && bash ${script_dirpath}/reload-files.sh ${flags_str})" \
    --scheme=path \
    --preview="bash ${script_dirpath}/preview.sh {}" > "${temp_output_file}" || exit_code=$?
exit_code=${exit_code:-0}

if [ "$exit_code" -ne 0 ]; then
    exit 1
fi

while IFS="" read -r line; do  # IFS="" -> no splitting (we may have paths with spaces)
    output_paths+=("${line}")
done < "${temp_output_file}"

dirs=()
text_files=()
open_targets=()
if [ "${#output_paths[@]}" -gt 0 ]; then
for output in "${output_paths[@]}"; do
    case "${output}" in
        HOME)
            dirs+=("${HOME}")
            ;;
        *.key)   # Mac's keynote presentation files are 'application/zip' MIME type, so we have to identify by extension
            open_targets+=("${output}")
            ;;
        *)
            case $(file -b --mime-type "${output}") in
                text/*)
                    text_files+=("${output}")
                    ;;
                application/json)
                    text_files+=("${output}")
                    ;;
                inode/directory)
                    dirs+=("${output}")
                    ;;
                application/pdf)
                    open_targets+=("${output}")
                    ;;
                application/vnd.openxmlformats-officedocument.wordprocessingml.document)
                    open_targets+=("${output}")
                    ;;
                image/*)
                    open_targets+=("${output}")
                    ;;
            esac
            ;;
    esac
done
fi

# We can open open_targets here (no need to pass them to the parent)
if [ "${#open_targets[@]}" -gt 0 ]; then
    for open_target_filepath in "${open_targets[@]}"; do
        open "${open_target_filepath}"
    done
fi

# However, text files & dirs need to be passed to the parent, so they
# get run in the user's shell process (and not this subprocess)

text_files_filepath=""
if [ "${#text_files[@]}" -gt 0 ]; then
    text_files_filepath="$(mktemp)"
    printf "%s\n" "${text_files[@]}" > "${text_files_filepath}"
fi

num_dirs="${#dirs[@]}"

dir_to_cd=""
if [ "${num_dirs}" -eq 1 ]; then
    dir_to_cd="${dirs[0]}"
elif [ "${num_dirs}" -gt 1 ]; then
    echo "Error: Cannot cd to more than one directory at a time" >&2
    exit 1
fi

# We put the tmp filepath first because we know it doesn't have a pipe
# This allows us to split on comma (because the dir to cd might have a pipe)
echo "${text_files_filepath}|${dir_to_cd}"
