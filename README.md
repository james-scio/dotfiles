# Dotfiles

Cross-platform (macOS + Linux) dotfiles with one-command setup.

## Quick Setup

```bash
git clone git@github.com:james-scio/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

Existing config files are backed up to `~/.dotfiles-backup/` before symlinking.

## What `install.sh` Does

1. **Linux only:** installs zsh, tmux, fzf, and neovim if missing; sets zsh as default shell
2. Links platform-specific git config (`gitconfig-darwin` or `gitconfig-linux`)
3. Creates symlinks for all config files (see [Structure](#structure))
4. Merges `editorMode=vim` into `~/.claude.json`
5. Enables Claude Code agent teams in `~/.claude/settings.json`
6. **macOS only:** installs launchd agents for Coder credential sync and Claude session pull
7. Installs neovim plugins via Lazy

## Structure

### `zsh/` - Modular zsh config

- **zshrc** - Entry point, sources all modules and sets up completion with menu selection
- **aliases.zsh** - Editor aliases (`vi`/`vim` -> nvim), grep color, `EDITOR`/`KUBE_EDITOR`
- **history.zsh** - 100k line history, dedup, incremental append, Dvorak layout
- **keybindings.zsh** - Vi mode with instant escape, smart `J` that collapses backslash-continued lines
- **prompt.zsh** - Custom async prompt (`prompt james`)
- **functions.zsh** - `mdcd` (mkdir+cd), `up N` (cd up N dirs), `jt` (toggle java/javatests), terminal title setting
- **platform-darwin.zsh** - macOS paths, Homebrew, gcloud, Bazel, fzf, mise
- **platform-linux.zsh** - Linux paths, LS_COLORS, fzf with vi-mode rebinds

### `tmux/` - tmux configuration

Vi mode, mouse support, 256-color with true color, Alt-arrow pane navigation, Ctrl-arrow window switching, Ctrl-Space copy mode, OSC clipboard, prompt-mark jumping (`.`/`,`), dark color scheme with inactive pane dimming, tmux-logging plugin via TPM.

### `nvim/` - Neovim (LazyVim)

Dark+ colorscheme with transparent background, treesitter for Python/Lua/Bash/JSON/YAML/Markdown/Java/Go, fzf-lua file finder (`Ctrl-F`), OSC 52 clipboard over SSH, 2-space indent, smart indent, visual break indent, mouse disabled.

### `alacritty/` - Alacritty terminal

- **alacritty.toml** - Input Mono font, `option_as_alt`, disables Cmd-Q/Cmd-W quit/close bindings

### `git/` - Git configuration

- **gitconfig** - GPG commit signing, histogram diff, git-town aliases (`hack`, `sync`, `ship`, `propose`, etc.), `bb` (better branch list), `pushf` (force-with-lease), rerere, auto-prune fetch, SSH URL rewriting, Bazel lockfile merge driver
- **gitconfig-darwin** - Meld merge tool, git-maintenance repos, GitButler signing
- **gitconfig-linux** - vimdiff merge tool
- **ignore** - Global gitignore

### `readline/` - Line editing

- **inputrc** - Vi editing mode for Bash/readline programs
- **editrc** - Vi bindings for editline (e.g., mysql CLI)

### `shell/` - Login shell

- **profile** - `~/.profile` for non-zsh login shells (bash, Claude Code), sets `EDITOR`/`VISUAL` to nvim, adds `~/bin` and `~/.local/bin` to PATH

### `claude/` - Claude Code project settings

## Coder Scripts

Helper scripts for syncing dotfiles and credentials to remote [Coder](https://coder.com) workspaces.

| Script | What it does |
|---|---|
| `push-to-coder.sh <workspace>` | Rsync dotfiles to a Coder workspace and run `install.sh` remotely |
| `sync-coder-creds.sh` | Sync gcloud credentials to all running Coder workspaces (tracks per-workspace sync state, skips already-synced) |
| `pull-claude-sessions.sh` | Pull Claude Code sessions from running Coder workspaces into local `~/.claude/projects/`, remapping remote paths to local equivalents |

### macOS Launch Agents (`launchd/`)

Three scripts run automatically via launchd on macOS. The plist files are in `launchd/` and are symlinked into `~/Library/LaunchAgents/` by `install.sh`.

| Plist | Script | Interval |
|---|---|---|
| `com.dotfiles.sync-coder-creds.plist` | `sync-coder-creds.sh` | Every 5 minutes |
| `com.dotfiles.pull-claude-sessions.plist` | `pull-claude-sessions.sh` | Every hour |
| `com.dotfiles.cleanup-nonbazel.plist` | `macos/cleanup-nonbazel.sh` | Daily at 03:30 |

The cleanup agent prunes selected rebuildable package/development caches, removes older versioned JetBrains caches while retaining the newest per product, and removes explicitly identified disposable backups. It intentionally excludes Bazel, Docker/Colima VM data, Trash, source trees, active environments, and current IDE support data.

Logs go to `/tmp/sync-coder-creds.log`, `/tmp/pull-claude-sessions.log`, and `/tmp/dotfiles-clean-nonbazel.log`.

To check status or stop manually:

```bash
launchctl list | grep com.dotfiles
launchctl bootout gui/$(id -u)/com.dotfiles.sync-coder-creds
launchctl bootout gui/$(id -u)/com.dotfiles.pull-claude-sessions
launchctl bootout gui/$(id -u)/com.dotfiles.cleanup-nonbazel
```

## Adding a New App

1. Create a directory (e.g., `alacritty/`)
2. Add the symlink mapping to the `link` calls in `install.sh`
