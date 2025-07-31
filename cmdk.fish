# ARGS:
#   -o  Only list the contents of the current directory at depth 1 (original behavior)
#   -s  List all contents of the current directory recursively (subdirectories)
function cmdk
    # If the CMDK_DIRPATH var is set, it's assumed to be where the the 'cmdk' repo (https://github.com/mieubrisse/cmdk) is checked out
    # Otherwise, use ~/.cmdk
    if test -z "$CMDK_DIRPATH"
        set cmdk_dirpath "$HOME/.cmdk"
    else
        set cmdk_dirpath "$CMDK_DIRPATH"
    end

    set core_response (bash "$cmdk_dirpath/cmdk-core.sh" $argv)
    if test $status -ne 0
        return 1
    end

    set response_parts (string split "|" $core_response)
    set text_files_filepath $response_parts[1]
    set dir_to_cd $response_parts[2]

    if test -n "$dir_to_cd"
        cd "$dir_to_cd"
    end

    if test -n "$text_files_filepath"
        set text_files

        # Read lines from the file into array
        while read -l line
            set text_files $text_files "$line"
        end < "$text_files_filepath"

        if test (count $text_files) -gt 0
            if test -n "$EDITOR"
                $EDITOR $text_files
            else
                vim -O $text_files
            end
        end
    end
end