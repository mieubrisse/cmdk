#!/usr/bin/env sh

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

fd_base_cmd="fd --follow --hidden --color=always"

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
    for dir in "$@"; do
        excludes="${excludes} -E ${dir}"
    done
    echo "${excludes}"
}

# Build common exclude arguments
common_exclude_args=$(build_excludes "${common_exclude_dirs[@]}")
home_exclude_args=$(build_excludes "${home_exclude_dirs[@]}")

# If the user passes in a '-o' argument, we only list the contents of the current directory
if [ "${1:-}" = "-o" ]; then
    ${fd_base_cmd} --max-depth 1 ${common_exclude_args} .
    # Add back excluded directories if they exist
    for dir in "${common_exclude_dirs[@]}"; do
        if [ -d "./${dir}" ]; then
            echo "./${dir}"
        fi
    done
    exit
fi

# !!! NOTE !!!! order is important!!
# fzf gives higher weight to lines earlier in the input, so we put most relevant things first

if [ "${PWD}" = "${HOME}" ]; then
    # Skip several directories in home that contain a bunch of garbage
    ${fd_base_cmd} --strip-cwd-prefix ${home_exclude_args} ${common_exclude_args} .
else
    ${fd_base_cmd} --strip-cwd-prefix ${common_exclude_args} .
fi

echo 'HOME'   # HOME
echo '..'     # Parent directory

# If we're not in the home directory, include stuff in the home directory
if [ "${PWD}" != "${HOME}" ]; then
    # Skip the Applications and Library in the home directory; they contain a bunch of garbage
    ${fd_base_cmd} ${home_exclude_args} ${common_exclude_args} . "${HOME}"
fi

echo '/tmp/'  # /tmp

echo '/'      # Root
${fd_base_cmd} --exact-depth 1 . / # Show one level of root

# Add back home directories just in case the user wants to 'cd' to them
for dir in "${home_exclude_dirs[@]}"; do
    if [ -d "${HOME}/${dir}" ]; then
        echo "${HOME}/${dir}"
    fi
done

# Add back common project directories so they can be navigated to
# Check if these directories exist in the current directory and add them
for dir in "${common_exclude_dirs[@]}"; do
    if [ -d "./${dir}" ]; then
        echo "./${dir}"
    fi
done

# If we're not in home, also check for these directories in home
if [ "${PWD}" != "${HOME}" ]; then
    for dir in "${common_exclude_dirs[@]}"; do
        if [ -d "${HOME}/${dir}" ]; then
            echo "${HOME}/${dir}"
        fi
    done
fi
