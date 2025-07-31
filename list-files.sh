#!/usr/bin/env sh

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"


# Common project directories to exclude
common_exclude_dirs=(
    'node_modules'
    '.git'
    'dist'
    'build'
    'target'
    '.next'
    '.nuxt'
    'coverage'
    '.pytest_cache'
    '__pycache__'
    '.venv'
    'vendor'
    '.tox'
    '.mypy_cache'
    '.ruff_cache'
    '.turbo'
    'out'
    '.parcel-cache'
    '.terraform'
)

# Home-specific directories to exclude
home_exclude_dirs=(
    'Applications'
    'Library'
    '.pyenv'
    '.jenv'
    '.nvm'
    'go'
    'venvs'
    '.cursor'
    '.docker'
    '.vscode'
    '.cache'
    '.gradle'
    '.zsh_sessions'
)

# Build exclude arguments for fd command
build_excludes() {
    local excludes=""
    for dir in "${@}"; do
        excludes="${excludes} -E ${dir}"
    done
    echo "${excludes}"
}

# Build common exclude arguments
common_exclude_args="$(build_excludes "${common_exclude_dirs[@]}")"
home_exclude_args="$(build_excludes "${home_exclude_dirs[@]}")"

# The various modes that cmdk can operate in

SYSTEM_MODE="system"    # Show all files on the filesystem
PWD_MODE="pwd"          # Show only the files in the current directory
SUBDIRS_MODE="subdirs"  # Show all files in the current directory, and recurse into subdirectories


mode="${SYSTEM_MODE}"
for arg in "${@}"; do
    case "$arg" in
        -o)
            mode="${PWD_MODE}"
            ;;
        -s)
            mode="${SUBDIRS_MODE}"
            ;;
    esac
done

fd_base_cmd="fd --follow --hidden --color=always"

# --------------- Handle current directory ------------------
pwd_restriction=""
if [ "${mode}" = "${PWD_MODE}" ]; then
    pwd_restriction="--max-depth 1"
fi

home_excludes=""
add_back_home_excludes="false"
if [ "${PWD}" = "${HOME}" ]; then
    home_excludes="${home_exclude_args}"
    add_back_home_excludes="true"
fi

${fd_base_cmd} --strip-cwd-prefix ${pwd_restriction} ${common_exclude_args} .

# Now add back the directories (but not contents) of any common excludes we removed
# TODO there's a bug where they get excluded but not added back if they're in a subdirectory!
for dir in "${common_exclude_dirs[@]}"; do
    if [ -d "${PWD}/${dir}" ]; then
        echo "${dir}"
    fi
done

# And if we were in HOME, we also need to add back any of the home excludes that got removed
# TODO there's a bug where they get excluded but not added back if they're in a subdirectory!
for dir in "${home_exclude_dirs[@]}"; do
    if [ -d "${PWD}/${dir}" ]; then
        echo "${dir}"
    fi
done

# --------------- Handle system beyond current directory -------------------
if [ "${mode}" = "${SYSTEM_MODE}" ]; then
    # If we're not at home, add it in (with excludes)
    if [ "${PWD}" != "${HOME}" ]; then
        ${fd_base_cmd} ${home_exclude_args} ${common_exclude_args} . "${HOME}"

        # Add back common excluded directories in HOME
        # TODO there's a bug where they get excluded but not added back if they're in a subdirectory!
        for dir in "${common_exclude_dirs[@]}"; do
            if [ -d "${HOME}/${dir}" ]; then
                echo "${HOME}/${dir}"
            fi
        done

        # Add back home-specific excluded directories in HOME
        # TODO there's a bug where they get excluded but not added back if they're in a subdirectory!
        for dir in "${home_exclude_dirs[@]}"; do
            if [ -d "${HOME}/${dir}" ]; then
                echo "${HOME}/${dir}"
            fi
        done
    fi

    echo '/tmp/'  # /tmp

    echo '/'      # Root
    ${fd_base_cmd} --exact-depth 1 . / # Show one level of root
fi


# --------------- Ominpresent items ------------------------
echo "HOME"
echo ".."
