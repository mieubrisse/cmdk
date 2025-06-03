ls_base_cmd='ls --color=always'

case "${1}" in
    HOME)
        ${ls_base_cmd} "${HOME}"
        ;;
    *)
        case $(file -b --mime-type "${1}" ) in 
            text/*) 
                bat --color=always "${1}"
                ;; 
            inode/directory) 
                ${ls_base_cmd} "${1}"
                ;; 
            image/*) 
                tiv -w 100 -h 100 "${1}" 2>/dev/null
                ;; 
        esac
        ;;
esac
