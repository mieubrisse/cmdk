#!/usr/bin/env bash
# ARGS:
#   -o  Only list the contents of the current directory at depth 1 (original behavior)
#   -s  List all contents of the current directory recursively (subdirectories)
function cmdk() {
    # If the CMDK_DIRPATH var is set, it's assumed to be where the the 'cmdk' repo (https://github.com/mieubrisse/cmdk) is checked out
    # Otherwise, use ~/.cmdk
    if [ -z "${CMDK_DIRPATH}" ]; then
        cmdk_dirpath="${HOME}/.cmdk"
    else
        cmdk_dirpath="${CMDK_DIRPATH}"
    fi

    if ! core_response="$(bash "${cmdk_dirpath}/cmdk-core.sh" "${@}")"; then
        return 1
    fi

    IFS="|" read -r text_files_filepath dir_to_cd <<< "${core_response}"

    if [ -n "${dir_to_cd}" ]; then
        cd "${dir_to_cd}" || return 1
    fi

    if [ -n "${text_files_filepath}" ]; then
        text_files=()

        # Build an array that holds the editor command and its flags
        # We have to do this because zsh doesn't do word-splitting by default,
        # and we can't 'setopt SH_WORD_SPLIT' else we'd set it for the user's entire shell
        if [ -n "$ZSH_VERSION" ]; then
            # shellcheck disable=SC2296,SC2206
            editor_cmd=( ${(z)${EDITOR:-vim -O}} )
        else
            IFS=' ' read -r -a editor_cmd <<< "${EDITOR:-"vim -O"}"
        fi

        # We use the `|| -n "${line}" ]` construction because (ChatGPT):
        #
        #   read only returns 0 (success) when it sees a newline after then
        #   text it just read. When read returns 1, the loop body is skippedso
        #   the final, newline-less line is silently lost. The extra test fixes this.
        #
        while IFS= read -r line || [ -n "${line}" ]; do
            text_files+=("${line}")
        done < "${text_files_filepath}"

        echo "${text_files[@]}"

        if [ "${#text_files[@]}" -gt 0 ]; then
            "${editor_cmd[@]}" "${text_files[@]}"
        fi
    fi
}
