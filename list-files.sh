#!/usr/bin/env sh

set -euo pipefail
script_dirpath="$(cd "$(dirname "${0}")" && pwd)"

fd_base_cmd="fd --follow --hidden --color=always"

# If the user passes in a '-o' argument, we only list the contents of the current directory
if [ "${1:-}" = "-o" ]; then
    ${fd_base_cmd} --max-depth 1 .
    exit
fi

# !!! NOTE !!!! order is important!!
# fzf gives higher weight to lines earlier in the input, so we put most relevant things first

if [ "${PWD}" = "${HOME}" ]; then
    # Skip several directories in home that contain a bunch of garbage
    ${fd_base_cmd} --strip-cwd-prefix \
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
        .
else
    ${fd_base_cmd} --strip-cwd-prefix .
fi

echo 'HOME'   # HOME
echo '..'     # Parent directory

# If we're not in the home directory, include stuff in the home directory
if [ "${PWD}" != "${HOME}" ]; then
    # Skip the Applications and Library in the home directory; they contain a bunch of garbage
    ${fd_base_cmd} \
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
        . \
        "${HOME}"
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
