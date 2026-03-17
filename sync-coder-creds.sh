#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

# Sync gcloud/GPG credentials to all running Coder workspaces,
# but only if local gcloud creds have been refreshed since the last sync.

MARKER="$HOME/.cache/coder-creds-last-sync"
GCLOUD_DIR="$HOME/.config/gcloud"
SYNC_SCRIPT="$HOME/workspace/deploy/coder/coder-sync-creds.sh"

# Check if any gcloud cred file is newer than the last sync marker
needs_sync=false
if [[ ! -f "$MARKER" ]]; then
    needs_sync=true
else
    for f in "$GCLOUD_DIR"/application_default_credentials.json \
             "$GCLOUD_DIR"/credentials.db; do
        if [[ -f "$f" && "$f" -nt "$MARKER" ]]; then
            needs_sync=true
            break
        fi
    done
fi

if [[ "$needs_sync" == "false" ]]; then
    exit 0
fi

echo "$(date): gcloud creds refreshed, syncing to Coder workspaces..."

workspaces=$(coder list -o json 2>/dev/null | jq -r '.[] | select(.latest_build.status == "running") | .name')

if [[ -z "$workspaces" ]]; then
    echo "No running Coder workspaces found."
    exit 0
fi

failed=false
for ws in $workspaces; do
    name="${ws##*/}"
    echo "Syncing creds to $name ..."
    if "$SYNC_SCRIPT" "$name" --skip-gpg; then
        echo "Done: $name"
    else
        echo "Failed: $name"
        failed=true
    fi
done

if [[ "$failed" == "false" ]]; then
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
fi
