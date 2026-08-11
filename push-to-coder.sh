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
# Strip org prefix (e.g. "james/slack2" -> "slack2") for SSH host
SSH_HOST="coder.${WORKSPACE##*/}"

if [[ ! -d "$DOTFILES/.git" ]]; then
    echo "Error: $DOTFILES is not a Git repository" >&2
    exit 1
fi
ORIGIN_URL="$(git -C "$DOTFILES" remote get-url origin)"
printf -v ORIGIN_ARG '%q' "$ORIGIN_URL"

echo "Checking remote dotfiles repository ..."
REMOTE_REPO_STATE="$(ssh "$SSH_HOST" "bash -s -- $ORIGIN_ARG" <<'REMOTE'
set -euo pipefail

origin="$1"
dotfiles="$HOME/.dotfiles"

if git -C "$dotfiles" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    existing_origin="$(git -C "$dotfiles" remote get-url origin 2>/dev/null || true)"
    if [[ -z "$existing_origin" ]]; then
        git -C "$dotfiles" remote add origin "$origin"
    elif [[ "$existing_origin" != "$origin" ]]; then
        echo "Error: $dotfiles origin is $existing_origin, expected $origin" >&2
        exit 1
    fi
    echo '__DOTFILES_REPO_STATE__:preserve'
else
    if [[ -e "$dotfiles/.git" || -L "$dotfiles/.git" ]]; then
        echo "Error: $dotfiles has a non-repository .git entry" >&2
        exit 1
    fi
    echo '__DOTFILES_REPO_STATE__:bootstrap'
fi
REMOTE
)"

rsync_args=(-av --delete --no-links --exclude='gitconfig-local')
case "$REMOTE_REPO_STATE" in
*'__DOTFILES_REPO_STATE__:preserve'*)
    # Keep remote Git history, refs, and commits. The working tree below is
    # still refreshed from this machine, matching the existing push behavior.
    rsync_args+=(--exclude='.git')
    echo "Preserving existing Git metadata on $SSH_HOST"
    ;;
*'__DOTFILES_REPO_STATE__:bootstrap'*)
    # The first transfer includes .git, so bootstrap does not require GitHub
    # access before install.sh configures authentication on the workspace.
    echo "Bootstrapping Git metadata on $SSH_HOST from the local repository"
    ;;
*)
    echo "Error: could not determine the remote dotfiles repository state" >&2
    exit 1
    ;;
esac

echo "Syncing dotfiles to $SSH_HOST:~/.dotfiles/ ..."
rsync "${rsync_args[@]}" "$DOTFILES/" "$SSH_HOST:~/.dotfiles/"

echo "Running install.sh on $SSH_HOST ..."
ssh "$SSH_HOST" '~/.dotfiles/install.sh'

echo ""
echo "Done! Run: coder ssh $WORKSPACE"
