#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"  # darwin or linux

echo "Platform: $PLATFORM"

# 1. Platform setup (Linux only)
if [[ "$PLATFORM" == "linux" ]]; then
    NEED_APT=false
    for tool in zsh tmux; do
        if ! command -v "$tool" &>/dev/null; then
            NEED_APT=true
            break
        fi
    done
    if [[ "$NEED_APT" == "true" ]]; then
        sudo apt-get update
        for tool in zsh tmux; do
            if ! command -v "$tool" &>/dev/null; then
                echo "Installing $tool..."
                sudo apt-get install -y "$tool"
            fi
        done
    fi

    # Install fzf from GitHub releases (apt version is too old)
    if ! command -v fzf &>/dev/null || [[ "$(fzf --version | awk '{print $1}')" < "0.48" ]]; then
        echo "Installing fzf..."
        FZF_VERSION="$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | grep -Po '"tag_name": *"v?\K[^"]*')"
        curl -fLo /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz"
        tar -xzf /tmp/fzf.tar.gz -C /tmp fzf
        sudo mv /tmp/fzf /usr/local/bin/fzf
        rm -f /tmp/fzf.tar.gz
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
link "$HOME/.inputrc"              "$DOTFILES/readline/inputrc"
link "$HOME/.editrc"               "$DOTFILES/readline/editrc"
link "$HOME/.zlogin"               "$DOTFILES/zsh/zlogin"
link "$HOME/.profile"              "$DOTFILES/shell/profile"

# 4. Configure ~/.claude.json (Claude Code manages this file directly, so we merge rather than symlink)
python3 - <<'EOF'
import json, os
path = os.path.expanduser("~/.claude.json")
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
if data.get("editorMode") != "vim":
    data["editorMode"] = "vim"
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Set editorMode=vim in {path}")
else:
    print(f"editorMode already set to vim in {path}")
EOF

# 5. Configure ~/.claude/settings.json (merge env vars, don't symlink — Claude manages this file)
python3 - <<'EOF'
import json, os
path = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
env = data.setdefault("env", {})
if env.get("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS") != "1":
    env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in {path}")
else:
    print(f"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS already set in {path}")
EOF

# 6. Install launchd agents (macOS only)
if [[ "$PLATFORM" == "darwin" ]]; then
    for plist in "$DOTFILES"/launchd/*.plist; do
        name="$(basename "$plist")"
        dest="$HOME/Library/LaunchAgents/$name"
        label="${name%.plist}"
        launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        ln -sf "$plist" "$dest"
        launchctl bootstrap "gui/$(id -u)" "$dest"
        echo "Loaded launch agent $label"
    done
fi

# 7. Install nvim plugins (best-effort — may fail on fresh VMs before SSH keys are added)
if command -v nvim &>/dev/null; then
    echo "Installing nvim plugins..."
    if nvim --headless "+Lazy! install" +qa 2>&1; then
        echo "Nvim plugins installed."
    else
        echo "Nvim plugin install failed (run again after adding SSH key)."
    fi
fi

echo ""
echo "Done! Platform: $PLATFORM"
[[ "$PLATFORM" == "linux" ]] && echo "Restart your shell or run: exec zsh" || true
