path+=("$HOME/bin")
path+=("$HOME/.local/bin")
path+=("$HOME/go/bin")

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
