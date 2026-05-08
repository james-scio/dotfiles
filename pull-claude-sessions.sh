#!/usr/bin/env bash
set -euo pipefail
exec > >(while IFS= read -r line; do printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done) 2>&1
export PATH="/opt/homebrew/bin:$PATH"

# Pull Claude Code sessions from all running Coder workspaces into local ~/.claude/projects/
# Remote project dirs like -home-workspace-foo get remapped to -Users-james-workspace-foo

# Get running workspace names (org/name format)
workspaces=$(coder list -o json 2>/dev/null | jq -r '.[] | select(.latest_build.status == "running") | .name')

if [[ -z "$workspaces" ]]; then
    echo "No running Coder workspaces found."
    exit 0
fi

for ws in $workspaces; do
    ssh_host="coder.${ws##*/}"
    echo "Pulling sessions from $ssh_host ..."

    for tool in .claude .erasmus; do
        local_projects="$HOME/$tool/projects"
        remote_dirs=$(ssh "$ssh_host" "ls ~/$tool/projects/ 2>/dev/null" 2>/dev/null | grep '^-') || true
        if [[ -z "$remote_dirs" ]]; then
            continue
        fi

        for remote_dir in $remote_dirs; do
            local_dir=$(echo "$remote_dir" | sed 's|^-home-[^-]*-workspace-|-Users-james-workspace-|; s|^-home-workspace-|-Users-james-workspace-|')
            mkdir -p "$local_projects/$local_dir"
            rsync -a --ignore-existing \
                "$ssh_host:~/$tool/projects/$remote_dir/" \
                "$local_projects/$local_dir/"
            echo "  [$tool] $remote_dir -> $local_dir"
        done
    done
done

echo "Done."
