#!/usr/bin/env bash
set -euo pipefail

# Pull Claude Code sessions from all running Coder workspaces into local ~/.claude/projects/
# Remote project dirs like -home-workspace-foo get remapped to -Users-james-workspace-foo

LOCAL_PROJECTS="$HOME/.claude/projects"

# Get running workspace names (org/name format)
workspaces=$(coder list -o json 2>/dev/null | jq -r '.[] | select(.latest_build.status == "running") | .name')

if [[ -z "$workspaces" ]]; then
    echo "No running Coder workspaces found."
    exit 0
fi

for ws in $workspaces; do
    ssh_host="coder.${ws##*/}"
    echo "Pulling sessions from $ssh_host ..."

    # Get list of remote project dirs (suppress coder version warnings on stderr)
    remote_dirs=$(ssh "$ssh_host" 'ls ~/.claude/projects/ 2>/dev/null' 2>/dev/null | grep '^-') || true
    if [[ -z "$remote_dirs" ]]; then
        echo "  No sessions found."
        continue
    fi

    for remote_dir in $remote_dirs; do
        # Remap: -home-{anything}-workspace-X -> -Users-james-workspace-X
        local_dir=$(echo "$remote_dir" | sed 's|^-home-[^-]*-workspace-|-Users-james-workspace-|; s|^-home-workspace-|-Users-james-workspace-|')
        mkdir -p "$LOCAL_PROJECTS/$local_dir"
        rsync -a --ignore-existing \
            "$ssh_host:~/.claude/projects/$remote_dir/" \
            "$LOCAL_PROJECTS/$local_dir/"
        echo "  $remote_dir -> $local_dir"
    done
done

echo "Done."
