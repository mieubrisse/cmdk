# ARGS:
#   -o  Only list the contents of the current directory (useful to have a second iTerm keybinding for this; I've chosen Cmd-l)
function cmdk() {
    # If the CMDK_DIRPATH var is set, it's assumed to be where the the 'cmdk' repo (https://github.com/mieubrisse/cmdk) is checked out
    # Otherwise, use ~/.cmdk
    if [ -z "${CMDK_DIRPATH}" ]; then
        local cmdk_dirpath="${HOME}/.cmdk"
    else
        local cmdk_dirpath="${CMDK_DIRPATH}"
    fi

    local cmd_filepath
    if ! cmd_filepath="$(bash "${CMDK_DIRPATH}/cmdk-core.sh" ${1})"; then
        return 1
    fi

    local cmd=()
    while IFS='' read -r line || [ -n "${line}" ]; do
      cmd+=("${line}")
    done < "${cmd_filepath}"

    echo "${cmd[@]}"

    if [ -n "${ZSH_VERSION}" ]; then
        local line="${(j: :)${(q)@}}"  # quote each word, join with spaces
        print -rs -- "$line"           # -s: add to hist, -r: raw (no escapes)
    elif [ -n "${BASH_VERSION}" ]; then
        local line="$(printf '%q ' "${cmd}")"
        history -s "${line}"
    else
        echo "Unrecognized shell; command won't be added to the history"
        echo "File an issue here to get it added: https://github.com/mieubrisse/cmdk/issues/new"
    fi

    "${cmd[@]}"
}
