#!/usr/bin/env sh

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

fd_base_cmd="fd --follow --hidden --color=always"

# Common project directories to exclude
common_excludes="\
    -E 'node_modules' \
    -E '.git' \
    -E 'dist' \
    -E 'build' \
    -E 'target' \
    -E '.next' \
    -E '.nuxt' \
    -E 'coverage' \
    -E '.pytest_cache' \
    -E '__pycache__' \
    -E '.venv' \
    -E 'vendor' \
    -E '.tox' \
    -E '.mypy_cache' \
    -E '.ruff_cache' \
    -E '.turbo' \
    -E 'out' \
    -E '.parcel-cache' \
    -E '.terraform'"

# If the user passes in a '-O' argument, we only list the contents of the current directory (max depth 1)
if [ "${1:-}" = "-O" ]; then
    eval "${fd_base_cmd} --max-depth 1 ${common_excludes} ."
    exit
fi

# If the user passes in a '-o' argument, we list all contents of the current directory recursively
if [ "${1:-}" = "-o" ]; then
    eval "${fd_base_cmd} ${common_excludes} ."
    exit
fi

# !!! NOTE !!!! order is important!!
# fzf gives higher weight to lines earlier in the input, so we put most relevant things first

if [ "${PWD}" = "${HOME}" ]; then
    # Skip several directories in home that contain a bunch of garbage
    eval "${fd_base_cmd} --strip-cwd-prefix \
        -E 'Applications' \
        -E 'Library' \
        -E '.pyenv' \
        -E '.jenv' \
        -E '.nvm' \
        -E 'go' \
        -E 'venvs' \
        -E '.cursor' \
        -E '.docker' \
        -E '.vscode' \
        -E '.cache' \
        -E '.gradle' \
        -E '.zsh_sessions' \
        ${common_excludes} \
        ."
else
    eval "${fd_base_cmd} --strip-cwd-prefix ${common_excludes} ."
fi

echo 'HOME'   # HOME
echo '..'     # Parent directory

# If we're not in the home directory, include stuff in the home directory
if [ "${PWD}" != "${HOME}" ]; then
    # Skip the Applications and Library in the home directory; they contain a bunch of garbage
    eval "${fd_base_cmd} \
        -E 'Applications' \
        -E 'Library' \
        -E '.pyenv' \
        -E '.jenv' \
        -E '.nvm' \
        -E 'go' \
        -E 'venvs' \
        -E '.cursor' \
        -E '.docker' \
        -E '.vscode' \
        -E '.cache' \
        -E '.gradle' \
        -E '.zsh_sessions' \
        ${common_excludes} \
        . \
        '${HOME}'"
fi

echo '/tmp/'  # /tmp

echo '/'      # Root
${fd_base_cmd} --exact-depth 1 . / # Show one level of root

# Add back .pyenv and .jenv just in case the user wants to 'cd' to them
echo "${HOME}/.pyenv"
echo "${HOME}/.jenv"
echo "${HOME}/.nvm"
echo "${HOME}/go"
echo "${HOME}/venvs"
echo "${HOME}/.cursor"
echo "${HOME}/.docker"
echo "${HOME}/.vscode"
echo "${HOME}/.cache"
echo "${HOME}/.gradle"
echo "${HOME}/.zsh_sessions"

# Add back common project directories so they can be navigated to
# Check if these directories exist in the current directory and add them
for dir in node_modules .git dist build target .next .nuxt coverage .pytest_cache __pycache__ .venv vendor .tox .mypy_cache .ruff_cache .turbo out .parcel-cache .terraform; do
    if [ -d "./${dir}" ]; then
        echo "./${dir}"
    fi
done

# If we're not in home, also check for these directories in home
if [ "${PWD}" != "${HOME}" ]; then
    for dir in node_modules .git dist build target .next .nuxt coverage .pytest_cache __pycache__ .venv vendor .tox .mypy_cache .ruff_cache .turbo out .parcel-cache .terraform; do
        if [ -d "${HOME}/${dir}" ]; then
            echo "${HOME}/${dir}"
        fi
    done
fi
