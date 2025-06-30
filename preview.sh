ls_base_cmd='ls --color=always'

bat_base_cmd="bat --color=always"

case "${1}" in
    HOME)
        ${ls_base_cmd} "${HOME}"
        ;;
    *)
        case $(file -b --mime-type "${1}" ) in 
            text/*) 
                ${bat_base_cmd} "${1}"
                ;; 
            application/json)
                ${bat_base_cmd} "${1}"
                ;; 
            inode/directory) 
                ${ls_base_cmd} "${1}"
                ;; 
            image/*) 
                tiv -w 100 -h 100 "${1}" 2>/dev/null
                ;; 
            application/zip)
                unzip -l "${1}"
                ;;
        esac
        ;;
esac
