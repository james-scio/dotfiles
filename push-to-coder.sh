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
SSH_HOST="coder.$WORKSPACE"

echo "Syncing dotfiles to $SSH_HOST:~/.dotfiles/ ..."
rsync -av --delete --exclude='.git' --exclude='gitconfig-local' \
    "$DOTFILES/" "$SSH_HOST:~/.dotfiles/"

echo "Running install.sh on $SSH_HOST ..."
ssh "$SSH_HOST" '~/.dotfiles/install.sh'

echo ""
echo "Done! Run: coder ssh $WORKSPACE"
