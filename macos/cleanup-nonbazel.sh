#!/bin/bash
# Remove selected rebuildable development caches and known disposable backups.
#
# Scope is intentionally explicit. This script does NOT touch Bazel, Docker,
# Colima VM data, Trash, source trees, active Python environments, Maven/Go
# module repositories, or current IDE settings/support data.
#
# Set DRY_RUN=1 to print actions without changing anything.

set -u

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"

HOME_DIR="${HOME:?HOME must be set}"
DRY_RUN="${DRY_RUN:-0}"
LOCK_DIR="/tmp/dotfiles-clean-nonbazel-${UID}.lock"

log() {
    printf '[cleanup] %s\n' "$*"
}

warn() {
    printf '[cleanup] WARNING: %s\n' "$*" >&2
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    log "Skipping: this cleanup is macOS-only."
    exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
    warn "Refusing to run as root."
    exit 1
fi

# Prevent overlapping launchd/manual runs.
if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    log "Another cleanup run is already in progress; exiting."
    exit 0
fi
trap '/bin/rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi

    "$@" || warn "Command failed: $*"
}

remove_path() {
    local path="$1"

    # Guard against accidental expansion or an unsafe path.
    case "$path" in
        "$HOME_DIR"/*) ;;
        *)
            warn "Refusing to remove path outside HOME: $path"
            return 1
            ;;
    esac

    if [[ ! -e "$path" && ! -L "$path" ]]; then
        return 0
    fi

    log "Removing $path"
    if [[ "$DRY_RUN" == "1" ]]; then
        return 0
    fi

    /bin/rm -rf -- "$path" || warn "Could not remove $path"
}

run_if_available() {
    local command_name="$1"
    shift

    if command -v "$command_name" >/dev/null 2>&1; then
        log "Running: $command_name $*"
        run "$command_name" "$@"
    else
        log "Skipping unavailable command: $command_name"
    fi
}

# Package-manager caches. These commands remove only rebuildable cache data.
run_if_available brew cleanup
run_if_available pip3 cache purge
run_if_available npm cache clean --force

# uv and pre-commit may only be installed inside a project environment. Use
# their native pruning commands when available, otherwise remove their known
# cache roots directly.
if command -v uv >/dev/null 2>&1; then
    log "Running: uv cache prune"
    run uv cache prune
else
    remove_path "$HOME_DIR/.cache/uv"
fi

if command -v pre-commit >/dev/null 2>&1; then
    log "Running: pre-commit clean"
    run pre-commit clean
else
    remove_path "$HOME_DIR/.cache/pre-commit"
fi

# Coursier cache contains downloadable artifacts and is safe to rebuild.
remove_path "$HOME_DIR/Library/Caches/Coursier"

# Remove older versioned JetBrains caches while retaining the newest version
# found for each product. This is intentionally version-aware so new IDE
# releases do not require editing this script. Unversioned directories such as
# Toolbox and Daemon are retained. Avoid deleting any JetBrains cache while an
# IDE or Gateway process is running.
jetbrains_cache_root="$HOME_DIR/Library/Caches/JetBrains"

# Sets JB_PRODUCT and JB_VERSION for names like GoLand2026.1 or
# IntelliJIdea2027.1.1. JB_VERSION is an integer sortable by Bash arithmetic.
jetbrains_metadata() {
    local name="$1"
    local patch=0

    if [[ "$name" =~ ^(.+)([0-9]{4})\.([0-9]+)(\.[0-9]+)?$ ]]; then
        JB_PRODUCT="${BASH_REMATCH[1]}"
        patch="${BASH_REMATCH[4]#.}"
        [[ -n "$patch" ]] || patch=0
        JB_VERSION=$((BASH_REMATCH[2] * 1000000 + BASH_REMATCH[3] * 1000 + patch))
        return 0
    fi

    return 1
}

if /usr/bin/pgrep -if 'idea|goland|pycharm|jetbrains.*gateway|gateway' >/dev/null 2>&1; then
    log "Skipping old JetBrains caches while a JetBrains process is running."
elif [[ -d "$jetbrains_cache_root" ]]; then
    for candidate in "$jetbrains_cache_root"/*; do
        [[ -d "$candidate" ]] || continue
        candidate_name="${candidate##*/}"
        jetbrains_metadata "$candidate_name" || continue
        candidate_product="$JB_PRODUCT"
        candidate_version="$JB_VERSION"
        has_newer=0

        for other in "$jetbrains_cache_root"/*; do
            [[ -d "$other" ]] || continue
            other_name="${other##*/}"
            jetbrains_metadata "$other_name" || continue
            if [[ "$JB_PRODUCT" == "$candidate_product" && "$JB_VERSION" -gt "$candidate_version" ]]; then
                has_newer=1
                break
            fi
        done

        if [[ "$has_newer" -eq 1 ]]; then
            remove_path "$candidate"
        fi
    done
fi

# Explicitly identified disposable backups. Do not use a broad '*backup*'
# glob outside JetBrains support data because the workspace contains source
# files and test fixtures with meaningful backup-related names.
jetbrains_support_root="$HOME_DIR/Library/Application Support/JetBrains"
for backup in "$jetbrains_support_root"/*-backup; do
    remove_path "$backup"
done
remove_path "$HOME_DIR/workspace/scio/python_scio/scio_env_backup"

log "Cleanup complete."
