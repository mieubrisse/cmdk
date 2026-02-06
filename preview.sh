#!/usr/bin/env bash

set -euo pipefail

if command -v bat >/dev/null 2>&1; then
    bat_base_cmd="bat --style=plain --color=always"
else
    bat_base_cmd="cat"
fi

if ls --color=always / >/dev/null 2>&1; then
    ls_base_cmd='ls --color=always'
else
    ls_base_cmd='ls -G'
fi

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
                if command -v tiv >/dev/null 2>&1; then
                    tiv -w 100 -h 100 "${1}" 2>/dev/null
                else
                    echo "[image preview requires tiv]"
                fi
                ;; 
            application/zip)
                if command -v unzip >/dev/null 2>&1; then
                    unzip -l "${1}"
                else
                    echo "[zip preview requires unzip]"
                fi
                ;;
            application/pdf)
                if command -v pdftotext >/dev/null 2>&1; then
                    pdftotext "${1}" -
                else
                    echo "[PDF preview requires pdftotext]"
                fi
                ;;
        esac
        ;;
esac
