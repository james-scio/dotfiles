#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: push-to-coder.sh <workspace>"
    echo ""
    echo "Copies dotfiles to a coder workspace and runs install.sh remotely."
    echo ""
    echo "Available workspaces:"
    coder list -o json 2>/dev/null | jq -r '.[].name' 2>/dev/null || coder list
    exit 1
fi

WORKSPACE="$1"
DOTFILES="$HOME/.dotfiles"

echo "Copying dotfiles to $WORKSPACE:~/.dotfiles/ ..."
coder ssh "$WORKSPACE" -- rm -rf '~/.dotfiles'
coder ssh "$WORKSPACE" -- mkdir -p '~/.dotfiles'

# Use tar to preserve directory structure and avoid multiple round trips
tar -C "$DOTFILES" -cf - \
    --exclude='.git' \
    --exclude='gitconfig-local' \
    . \
    | coder ssh "$WORKSPACE" -- tar -C '~/.dotfiles' -xf -

echo "Running install.sh on $WORKSPACE ..."
coder ssh "$WORKSPACE" -- chmod +x '~/.dotfiles/install.sh'
coder ssh "$WORKSPACE" -- '~/.dotfiles/install.sh'

echo ""
echo "Done! Run: coder ssh $WORKSPACE"
