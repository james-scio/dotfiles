#!/usr/bin/env python3
"""Merge dotfiles-managed Codex defaults into the user config."""

import os
import pathlib
import re
import stat
import sys
import tempfile

source = pathlib.Path(sys.argv[1])
target = pathlib.Path.home() / ".codex" / "config.toml"
managed_keys = {"approval_policy", "approvals_reviewer", "sandbox_mode"}
managed_tui_keys = {"vim_mode_default"}
managed_lines = []
managed_tui_lines = []
source_section = ""
for line in source.read_text().splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if stripped.startswith("[") and stripped.endswith("]"):
        source_section = stripped[1:-1].strip()
        if source_section != "tui":
            raise SystemExit(f"Invalid Codex default section in {source}: {line}")
        continue
    if source_section == "tui":
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(true|false)", stripped)
        if not match or match.group(1) not in managed_tui_keys:
            raise SystemExit(f"Invalid Codex TUI default in {source}: {line}")
        managed_tui_lines.append(stripped)
    else:
        match = re.fullmatch(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"[^"\\]*"', stripped)
        if not match or match.group(1) not in managed_keys:
            raise SystemExit(f"Invalid Codex default in {source}: {line}")
        managed_lines.append(stripped)
if (
    len(managed_lines) != len(managed_keys)
    or {line.split("=", 1)[0].strip() for line in managed_lines} != managed_keys
):
    raise SystemExit(
        f"Expected exactly these Codex defaults in {source}: {sorted(managed_keys)}"
    )
if (
    len(managed_tui_lines) != len(managed_tui_keys)
    or {line.split("=", 1)[0].strip() for line in managed_tui_lines} != managed_tui_keys
):
    raise SystemExit(
        f"Expected exactly these Codex TUI defaults in {source}: {sorted(managed_tui_keys)}"
    )

# Resolve a symlink so an existing linked config is updated, not replaced.
if target.is_symlink():
    target = target.resolve()
existing = target.read_text() if target.is_file() else ""
lines = existing.splitlines()
marker = "# Managed by dotfiles/install.sh; keep the workspace sandbox enabled."
preserved = []
section = ""
tui_section_seen = False
tui_setting_written = False
for line in lines:
    stripped = line.strip()
    if stripped == marker:
        continue
    if stripped.startswith("[") and stripped.endswith("]"):
        if section == "tui" and not tui_setting_written:
            preserved.extend(managed_tui_lines)
            tui_setting_written = True
        section = stripped[1:-1].strip()
        if section == "tui":
            tui_section_seen = True
        preserved.append(line)
        continue
    match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
    if section == "" and match and match.group(1) in managed_keys:
        continue
    if section == "tui" and match and match.group(1) in managed_tui_keys:
        if not tui_setting_written:
            preserved.extend(managed_tui_lines)
            tui_setting_written = True
        continue
    preserved.append(line)
if section == "tui" and not tui_setting_written:
    preserved.extend(managed_tui_lines)
    tui_setting_written = True
if not tui_section_seen:
    preserved.extend(["", "[tui]", *managed_tui_lines])

block = marker + "\n" + "\n".join(managed_lines)
updated = block + ("\n\n" + "\n".join(preserved).lstrip("\n") if preserved else "") + "\n"
if updated == existing:
    print(f"Codex defaults already set in {target}")
else:
    target.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix=target.name + ".", dir=target.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w") as output:
            output.write(updated)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, target)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise
    print(f"Set Codex defaults in {target}")
