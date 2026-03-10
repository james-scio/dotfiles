# Dotfiles

## Quick Setup

```bash
git clone git@github.com:jamessimo/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

Existing config files are backed up to `~/.dotfiles-backup/` before symlinking.

## Structure

- `zsh/` - Modular zsh config with platform-specific files
- `tmux/` - tmux configuration
- `nvim/` - Neovim (LazyVim) configuration
- `git/` - Git config with platform includes
- `claude/` - Claude Code settings

## Adding a New App

1. Create a directory (e.g., `alacritty/`)
2. Add the symlink mapping to the `LINKS` array in `install.sh`
