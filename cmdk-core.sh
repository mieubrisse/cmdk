#!/usr/bin/env bash

# This is the core of cmdk, written in Bash.
# The entrypoint cmdk.sh and cmdk.fish call down to this
#
# Rationale: I didn't want to rewrite the entire thing to be zsh-
# and fish-compatible :S

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

output_paths=()

# EXPLANATION:
# -m allows multiple selections
# --ansi tells fzf to parse the ANSI color codes that we're generating with fd
# --scheme=path optimizes for path-based input
# --with-nth allows us to use the custom sorting mechanism
fzf_output=$(FZF_DEFAULT_COMMAND="sh ${script_dirpath}/list-files.sh ${1:-}" fzf \
    -m \
    --ansi \
    --bind='change:top' \
    --scheme=path \
    --preview="sh ${script_dirpath}/preview.sh {}")

if [ "${?}" -ne 0 ]; then
    exit 1
fi

while IFS="" read -r line; do  # IFS="" -> no splitting (we may have paths with spaces)
    output_paths+=("${line}")
done <<< "${fzf_output}"

dirs=()
text_files=()
open_targets=()
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

# We can open open_targets here (no need to pass them to the parent)
for open_target_filepath in "${open_targets[@]}"; do
    open "${open_target_filepath}"
done

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
