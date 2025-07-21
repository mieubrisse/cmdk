# ARGS:
#   -o  Only list the contents of the current directory (useful to have a second iTerm keybinding for this; I've chosen Cmd-l)
function cmdk() {
    # If the CMDK_DIRPATH var is set, it's assumed to be where the the 'cmdk' repo (https://github.com/mieubrisse/cmdk) is checked out
    # Otherwise, use ~/.cmdk
    if [ -z "${CMDK_DIRPATH}" ]; then
        cmdk_dirpath="${HOME}/.cmdk"
    else
        cmdk_dirpath="${CMDK_DIRPATH}"
    fi

    if ! core_response="$(bash "${CMDK_DIRPATH}/cmdk-core.sh" ${1})"; then
        return 1
    fi

    IFS="|" read -r text_files_filepath dir_to_cd <<< "${core_response}"

    if [ -n "${dir_to_cd}" ]; then
        cd "${dir_to_cd}"
    fi

    if [ -n "${text_files_filepath}" ]; then
        text_files=()

        # We use the `|| -n "${line}" ]` construction because (ChatGPT):
        #
        #   read only returns 0 (success) when it sees a newline after then
        #   text it just read. When read returns 1, the loop body is skippedso
        #   the final, newline-less line is silently lost. The extra test fixes this.
        #
        while IFS= read -r line || [ -n "${line}" ]; do
            text_files+=("${line}")
        done < "${text_files_filepath}"

        if [ "${#text_files[@]}" -gt 0 ]; then
            ${EDITOR:-"vim -O"} "${text_files[@]}"
        fi
    fi
}
