path+=("$HOME/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/go/bin")

# Coder forces GIT_SSH_COMMAND through `coder gitssh`, which authenticates with
# Coder's own SSH key (not added to GitHub/GitLab). Override it to plain ssh so
# git uses the forwarded ssh-agent key instead.
case "${GIT_SSH_COMMAND:-}" in
    *"coder gitssh"*) export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" ;;
esac

# Coder's startup appends GIT_COMMITTER_NAME/EMAIL=glean-bot-user to ~/.bashrc,
# reattributing commits to the bot. Undo that override (it leaks into zsh when
# launched from a bash login shell) so commits use the gitconfig-linux user.
if [ "${GIT_COMMITTER_EMAIL:-}" = "glean-bot-user@glean.com" ]; then
    unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
fi

# Keep a stable ssh-agent socket across Coder SSH reconnects. Each `coder ssh`
# creates a new /tmp/auth-agent*/listener.sock and deletes the old one, so a
# reattached tmux pane (or the bazel daemon) ends up pointed at a dead socket →
# "Permission denied (publickey)" on every git-over-SSH op. A fresh login (which
# has the live forwarded socket) repoints ~/.ssh/agent.sock; all shells then use
# that stable path, so existing panes auto-heal on the next login.
if [[ -S "${SSH_AUTH_SOCK:-}" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]]; then
    mkdir -p "$HOME/.ssh"
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
fi
[[ -S "$HOME/.ssh/agent.sock" ]] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

# LS colors matching Mac LSCOLORS=gxfxbEaEBxxEhEhBaDaCaD
# Directories: cyan, symlinks: magenta, executables: blue bold
# Disable green background on sticky/other-writable dirs
export LS_COLORS='di=36:ln=35:so=31;1:pi=34;1:ex=34;1:bd=0:cd=0:su=37;1:sg=0:tw=36:ow=36'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'

# fzf
if command -v fzf &>/dev/null; then
    export FZF_CTRL_R_OPTS=$'--bind ctrl-/:toggle-wrap --wrap-sign "\t↳ "'
    # fzf 0.48+ supports `fzf --zsh`, older versions ship separate files
    if fzf --zsh &>/dev/null; then
        source <(fzf --zsh)
    else
        [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
        [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
    fi
    # Old fzf key-bindings.zsh binds to emacs keymap only; re-bind for vi mode
    bindkey -M viins '^R' fzf-history-widget
    bindkey -M viins '^T' fzf-file-widget
fi
