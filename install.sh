#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"  # darwin or linux

echo "Platform: $PLATFORM"

# 1. Platform setup (Linux only)
if [[ "$PLATFORM" == "linux" ]]; then
    if ! command -v zsh &>/dev/null; then
        echo "Installing zsh..."
        sudo apt-get update && sudo apt-get install -y zsh
    fi
    if [[ "$SHELL" != */zsh ]]; then
        echo "Setting default shell to zsh..."
        chsh -s "$(which zsh)"
    fi
    for tool in nvim tmux fzf; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Installing $tool..."
            sudo apt-get install -y "$tool" 2>/dev/null || echo "Could not install $tool, install manually"
        fi
    done
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

echo ""
echo "Done! Platform: $PLATFORM"
[[ "$PLATFORM" == "linux" ]] && echo "Restart your shell or run: exec zsh" || true
