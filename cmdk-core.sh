#!/usr/bin/env bash

# This is the core of cmdk, written in Bash.
# The entrypoint cmdk.sh and cmdk.fish call down to this
#
# Rationale: I didn't want to rewrite the entire thing to be zsh-
# and fish-compatible :S

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

output_paths=()

while IFS="" read -r line; do  # IFS="" -> no splitting (we may have paths with spaces)
    output_paths+=("${line}")
done < <(
    # EXPLANATION:
    # -m allows multiple selections
    # --ansi tells fzf to parse the ANSI color codes that we're generating with fd
    # --scheme=path optimizes for path-based input
    # --with-nth allows us to use the custom sorting mechanism
    FZF_DEFAULT_COMMAND="sh ${script_dirpath}/list-files.sh ${1:-}" fzf \
        -m \
        --ansi \
        --bind='change:top' \
        --scheme=path \
        --preview="sh ${script_dirpath}/preview.sh {}"
    if [ "${?}" -ne 0 ]; then
        return
    fi
)

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

if [ "${#dirs[@]}" -gt 1 ]; then
    echo "Error: Cannot cd to more than one directory at a time" >&2
    exit 1
fi

cmd_to_run=()

arrays=(
    "open_targets"
    "dirs"
    "text_files"
)
for arr in "${arrays[@]}"; do
    if [ $(eval 'echo ${#'${arr}'[@]}') -eq 0 ]; then
        continue
    fi

    if [ "${#cmd_to_run[@]}" -gt 0 ]; then
        cmd_to_run+=("&&")
    fi

    if [ "${arr}" = "open_targets" ]; then
        cmd_to_run+=( "open" "${open_targets[@]}" )
    elif [ "${arr}" = "dirs" ]; then
        cmd_to_run+=( "cd" "${dirs[0]}" )
    elif [ "${arr}" = "text_files" ]; then
        editor_str="${EDITOR:-vim -O}"
        cmd_to_run+=( ${editor_str} "${text_files[@]}" )
    fi
done

# This should never happen, because the user should be forced to pick at
# least one element to exit fzf successfully
if [ "${#cmd_to_run[@]}" -eq 0 ]; then
    echo "Error: Somehow there's no command to run; this is a bug with cmdk" >&2
    exit 1
fi

return_filepath="$(mktemp)"
printf "%s\n" "${cmd_to_run[@]}" > "${return_filepath}"

echo "${return_filepath}"
