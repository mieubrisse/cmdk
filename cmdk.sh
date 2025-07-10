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

    # EXPLANATION:
    # -m allows multiple selections
    # --ansi tells fzf to parse the ANSI color codes that we're generating with fd
    # --scheme=path optimizes for path-based input
    # --with-nth allows us to use the custom sorting mechanism
    IFS=$'\n' output_paths=( 
        $(FZF_DEFAULT_COMMAND="sh ${cmdk_dirpath}/list-files.sh ${1}" fzf \
            -m \
            --ansi \
            --bind='change:top' \
            --scheme=path \
            --preview="sh ${cmdk_dirpath}/preview.sh {}"
        )
    )
    if [ "${?}" -ne 0 ]; then
        return
    fi

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

    num_dirs="${#dirs[@]}"
    if [ "${num_dirs}" -eq 1 ]; then
        cd "${dirs[0]}"
    elif [ "${num_dirs}" -gt 1 ]; then
        echo "Error: Cannot cd to more than one directory at a time" >&2
        return 1
    fi

    for open_target_filepath in "${open_targets[@]}"; do
        open "${open_target_filepath}"
    done

    if [ "${#text_files[@]}" -gt 0 ]; then
        ${EDITOR:-vim -O} "${text_files[@]}"
    fi
}
