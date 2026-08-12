#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"  # darwin or linux

echo "Platform: $PLATFORM"

# 0. Undo Coder's git SSH override.
# Coder injects GIT_SSH_COMMAND=".../coder gitssh --", which authenticates with
# Coder's own SSH key (not added to GitHub/GitLab) and fails host-key checks on
# fresh VMs ("Host key verification failed"). This env var outranks git's
# core.sshCommand, so it can't be undone from gitconfig. Override it to plain
# ssh so git uses the forwarded ssh-agent key instead (e.g. for Lazy clones).
case "${GIT_SSH_COMMAND:-}" in
    *"coder gitssh"*)
        export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
        echo "Overrode Coder's GIT_SSH_COMMAND to use the forwarded ssh-agent key"
        ;;
esac

# 0b. Undo Coder's bot-committer override for bash.
# The workspace template appends GIT_COMMITTER_NAME/EMAIL=glean-bot-user to
# ~/.bashrc (re-added on rebuilds), reattributing commits to the bot. We don't
# delete those lines (they come back); instead append an unset at the very end
# of ~/.bashrc so it runs after them, restoring the committer to the gitconfig
# user. Every interactive/login bash sources .bashrc. Idempotent via marker.
if [[ "$PLATFORM" == "linux" && -f "$HOME/.bashrc" ]]; then
    MARKER="# dotfiles: undo Coder bot-committer override"
    if ! grep -qF "$MARKER" "$HOME/.bashrc"; then
        {
            echo ""
            echo "$MARKER"
            echo '[ "${GIT_COMMITTER_EMAIL:-}" = "glean-bot-user@glean.com" ] && unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL'
        } >> "$HOME/.bashrc"
        echo "Appended bot-committer unset to ~/.bashrc"
    fi
fi

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

    # Install tree-sitter-cli (needed by nvim-treesitter auto_install)
    if ! command -v tree-sitter &>/dev/null; then
        echo "Installing tree-sitter-cli..."
        TS_VERSION="$(curl -fsSL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest | grep -Po '"tag_name": *"v?\K[^"]*')"
        curl -fLo /tmp/tree-sitter.gz "https://github.com/tree-sitter/tree-sitter/releases/download/v${TS_VERSION}/tree-sitter-linux-x64.gz"
        gunzip -f /tmp/tree-sitter.gz
        chmod +x /tmp/tree-sitter
        sudo mv /tmp/tree-sitter /usr/local/bin/tree-sitter
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

# 1b. Platform setup (macOS)
if [[ "$PLATFORM" == "darwin" ]]; then
    if ! command -v tree-sitter &>/dev/null; then
        echo "Installing tree-sitter-cli..."
        brew install tree-sitter
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
link "$HOME/.config/alacritty/alacritty.toml" "$DOTFILES/alacritty/alacritty.toml"
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

    # Preinstall the parsers used by the config before the first interactive
    # nvim session. Running with -u NONE avoids the startup FileType
    # autocmd and gives first-time downloads/compiles five minutes. This is
    # intentionally independent of Lazy! install: its normal config can time
    # out while installing parsers on a new workspace.
    tree_sitter_languages=(python lua bash json yaml markdown java go gitcommit)
    tree_sitter_lua_list="$(printf "'%s', " "${tree_sitter_languages[@]}")"
    echo "Preinstalling nvim-treesitter parsers..."
    if nvim --headless -u NONE \
        --cmd "lua vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/nvim-treesitter')" \
        -c "lua require('nvim-treesitter').install({ ${tree_sitter_lua_list} }, { summary = false }):wait(300000)" \
        -c 'qa' 2>&1; then
        echo "Nvim-treesitter parsers installed."
    else
        echo "Nvim-treesitter parser preinstall failed (run install.sh again when network/authentication is available)."
    fi
fi

echo ""
echo "Done! Platform: $PLATFORM"
[[ "$PLATFORM" == "linux" ]] && echo "Restart your shell or run: exec zsh" || true
