path+=("$HOME/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/go/bin")

alias ls='ls --color=auto'
alias ll='ls -l --color=auto'

# fzf (if installed)
if command -v fzf &>/dev/null; then
    export FZF_CTRL_R_OPTS=$'--bind ctrl-/:toggle-wrap --wrap-sign "\t↳ "'
    source <(fzf --zsh) 2>/dev/null || true
fi
