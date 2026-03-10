path+=("$HOME/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/go/bin")

# LS colors matching Mac LSCOLORS=gxfxbEaEBxxEhEhBaDaCaD
# Directories: cyan, symlinks: magenta, executables: blue bold
# Disable green background on sticky/other-writable dirs
export LS_COLORS='di=36:ln=35:so=31;1:pi=34;1:ex=34;1:bd=0:cd=0:su=37;1:sg=0:tw=36:ow=36'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'

# fzf (if installed)
if command -v fzf &>/dev/null; then
    export FZF_CTRL_R_OPTS=$'--bind ctrl-/:toggle-wrap --wrap-sign "\t↳ "'
    source <(fzf --zsh) 2>/dev/null || true
fi
