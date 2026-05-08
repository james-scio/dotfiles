#!/usr/bin/env bash
set -euo pipefail
exec > >(while IFS= read -r line; do printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done) 2>&1
export PATH="/opt/homebrew/bin:$PATH"
source "$(dirname "$0")/shell/launchd-notify.sh" && launchd_notify_trap

# Sync gcloud/GPG credentials to all running Coder workspaces.
# Tracks per-workspace sync state so paused VMs get synced when they come online.

CREDS_MARKER="$HOME/.cache/coder-creds-changed"
SYNCED_DIR="$HOME/.cache/coder-creds-synced"
GCLOUD_DIR="$HOME/.config/gcloud"
SYNC_SCRIPT="$HOME/workspace/deploy/coder/coder-sync-creds.sh"

# Update the creds-changed marker if any cred file is newer than it
for f in "$GCLOUD_DIR"/application_default_credentials.json \
         "$GCLOUD_DIR"/credentials.db; do
    if [[ -f "$f" ]]; then
        if [[ ! -f "$CREDS_MARKER" || "$f" -nt "$CREDS_MARKER" ]]; then
            mkdir -p "$(dirname "$CREDS_MARKER")"
            touch "$CREDS_MARKER"
            break
        fi
    fi
done

# If creds have never been seen, nothing to sync
if [[ ! -f "$CREDS_MARKER" ]]; then
    exit 0
fi

workspaces=$(coder list -o json 2>/dev/null | jq -r '.[] | select(.latest_build.status == "running") | .name')

if [[ -z "$workspaces" ]]; then
    exit 0
fi

mkdir -p "$SYNCED_DIR"

# Collect workspaces that haven't been synced since creds last changed
needs_sync=()
for ws in $workspaces; do
    name="${ws##*/}"
    marker="$SYNCED_DIR/$name"
    if [[ ! -f "$marker" || "$CREDS_MARKER" -nt "$marker" ]]; then
        needs_sync+=("$name")
    fi
done

if [[ ${#needs_sync[@]} -eq 0 ]]; then
    exit 0
fi

echo "$(date): syncing creds to Coder workspaces: ${needs_sync[*]}"

for name in "${needs_sync[@]}"; do
    echo "Syncing creds to $name ..."
    if "$SYNC_SCRIPT" "$name" --skip-gpg; then
        echo "Done: $name"
        touch "$SYNCED_DIR/$name"
    else
        echo "Failed: $name"
    fi
done
