# Notify on first failure, clear on recovery. Source this, then call launchd_notify_trap.
# Uses the script's basename as the identifier.

_LAUNCHD_NOTIFY_NAME="$(basename "${BASH_SOURCE[1]}" .sh)"
_LAUNCHD_NOTIFY_MARKER="$HOME/.cache/launchd-failures/$_LAUNCHD_NOTIFY_NAME"

_launchd_notify_on_err() {
    if [[ ! -f "$_LAUNCHD_NOTIFY_MARKER" ]]; then
        mkdir -p "$(dirname "$_LAUNCHD_NOTIFY_MARKER")"
        touch "$_LAUNCHD_NOTIFY_MARKER"
        local log="/tmp/$_LAUNCHD_NOTIFY_NAME.log"
        local detail=""
        if [[ -f "$log" ]]; then
            detail=$(tail -1 "$log" | cut -c1-200)
        fi
        osascript -e "display notification \"${detail:-check log for details}\" with title \"$_LAUNCHD_NOTIFY_NAME\" subtitle \"failed\" sound name \"Basso\"" 2>/dev/null || true
    fi
}

_launchd_notify_on_exit() {
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        rm -f "$_LAUNCHD_NOTIFY_MARKER"
    else
        _launchd_notify_on_err
    fi
}

launchd_notify_trap() {
    trap '_launchd_notify_on_exit' EXIT
}
