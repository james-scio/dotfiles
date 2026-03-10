#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"  # darwin or linux

echo "Platform: $PLATFORM"

# 1. Platform setup (Linux only)
if [[ "$PLATFORM" == "linux" ]]; then
    NEED_APT=false
    for tool in zsh tmux fzf; do
        if ! command -v "$tool" &>/dev/null; then
            NEED_APT=true
            break
        fi
    done
    if [[ "$NEED_APT" == "true" ]]; then
        sudo apt-get update
        for tool in zsh tmux fzf; do
            if ! command -v "$tool" &>/dev/null; then
                echo "Installing $tool..."
                sudo apt-get install -y "$tool"
            fi
        done
    fi

    # Install nvim via appimage if missing (Ubuntu apt version is too old)
    if ! command -v nvim &>/dev/null; then
        echo "Installing nvim..."
        curl -fLo /tmp/nvim-linux-x86_64.appimage https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
        chmod +x /tmp/nvim-linux-x86_64.appimage
        sudo mv /tmp/nvim-linux-x86_64.appimage /usr/local/bin/nvim
    fi

    # Set default shell to zsh (sudo to avoid password prompt)
    if [[ "$SHELL" != */zsh ]]; then
        echo "Setting default shell to zsh..."
        sudo usermod -s "$(which zsh)" "$(whoami)"
    fi
fi

# 2. Set platform-specific git include
ln -sf "$DOTFILES/git/gitconfig-$PLATFORM" "$DOTFILES/git/gitconfig-local"
echo "Linked git config for $PLATFORM"

# 3. Create symlinks (backup existing non-symlink files first)
link() {
    local target="$1" source="$2"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$BACKUP"
        mv "$target" "$BACKUP/"
        echo "Backed up $target → $BACKUP/"
    fi
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    echo "Linked $target → $source"
}

link "$HOME/.zshrc"                "$DOTFILES/zsh/zshrc"
link "$HOME/.tmux.conf"            "$DOTFILES/tmux/tmux.conf"
link "$HOME/.gitconfig"            "$DOTFILES/git/gitconfig"
link "$HOME/.config/git/ignore"    "$DOTFILES/git/ignore"
link "$HOME/.config/nvim"          "$DOTFILES/nvim"
link "$HOME/.claude/settings.json" "$DOTFILES/claude/settings.json"
link "$HOME/.inputrc"              "$DOTFILES/readline/inputrc"
link "$HOME/.profile"              "$DOTFILES/shell/profile"

echo ""
echo "Done! Platform: $PLATFORM"
[[ "$PLATFORM" == "linux" ]] && echo "Restart your shell or run: exec zsh" || true
