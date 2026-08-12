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
GH_HOSTS="$HOME/.config/gh/hosts.yml"
GH_TOKEN_FINGERPRINT="$HOME/.cache/coder-gh-token-fingerprint"
SYNC_SCRIPT="$HOME/workspace/deploy/coder/coder-sync-creds.sh"
SCIO_SYNC_SCRIPT="$HOME/workspace/scio/coder/coder-sync-creds.sh"

# Push the laptop's Keychain-backed `gh` login to a workspace. gh may keep the
# token in macOS Keychain and leave only account metadata in hosts.yml, so do
# not copy hosts.yml verbatim. Generate a minimal hosts.yml from `gh auth token`.
push_gh_auth() {
    local name="$1"
    local token user
    command -v gh >/dev/null 2>&1 || return 0
    token="$(gh auth token --hostname github.com 2>/dev/null)" || return 0
    [[ -n "$token" ]] || return 0
    user="$(gh api user --hostname github.com --jq .login 2>/dev/null)" || return 0
    [[ -n "$user" ]] || return 0

    {
        printf 'github.com:\n'
        printf '    oauth_token: %s\n' "$token"
        printf '    user: %s\n' "$user"
        printf '    git_protocol: https\n'
    } | ssh "coder.$name" 'umask 077; mkdir -p ~/.config/gh; tmp=$(mktemp ~/.config/gh/hosts.yml.XXXXXX); cat > "$tmp"; chmod 600 "$tmp"; mv "$tmp" ~/.config/gh/hosts.yml'
}

# Update the creds-changed marker if any cred file is newer than it. The token
# fingerprint catches Keychain-backed gh refreshes even when hosts.yml itself
# contains no token and its mtime does not change.
for f in "$GCLOUD_DIR"/application_default_credentials.json \
         "$GCLOUD_DIR"/credentials.db \
         "$GH_HOSTS"; do
    if [[ -f "$f" ]]; then
        if [[ ! -f "$CREDS_MARKER" || "$f" -nt "$CREDS_MARKER" ]]; then
            mkdir -p "$(dirname "$CREDS_MARKER")"
            touch "$CREDS_MARKER"
            break
        fi
    fi
done

if command -v gh >/dev/null 2>&1; then
    gh_token="$(gh auth token --hostname github.com 2>/dev/null || true)"
    if [[ -n "$gh_token" ]]; then
        gh_fingerprint="$(printf '%s' "$gh_token" | shasum -a 256 | awk '{print $1}')"
        old_fingerprint="$(cat "$GH_TOKEN_FINGERPRINT" 2>/dev/null || true)"
        if [[ "$gh_fingerprint" != "$old_fingerprint" ]]; then
            mkdir -p "$(dirname "$GH_TOKEN_FINGERPRINT")"
            printf '%s\n' "$gh_fingerprint" > "$GH_TOKEN_FINGERPRINT"
            touch "$CREDS_MARKER"
        fi
    fi
fi

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
    if [[ "$name" == "creds1" ]]; then
        sync_cmd=("$SCIO_SYNC_SCRIPT" "$name" --skip-gpg --sa)
    else
        sync_cmd=("$SYNC_SCRIPT" "$name" --skip-gpg)
    fi
    if "${sync_cmd[@]}"; then
        push_gh_auth "$name" && echo "  gh auth synced" || echo "  gh auth sync failed (non-fatal)"
        echo "Done: $name"
        touch "$SYNCED_DIR/$name"
    else
        echo "Failed: $name"
    fi
done
