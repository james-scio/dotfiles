#!/usr/bin/env python3
"""Match the Mac's narrow Scio fetch configuration on existing clones/worktrees."""

import pathlib
import re
import subprocess
import sys


FETCH_REFSPECS = [
    f"+refs/heads/{branch}:refs/remotes/origin/{branch}"
    for branch in ("master", "james-*", "release-*")
]
SCIO_ORIGIN = re.compile(
    r"(?:git@github\.com:|(?:https?|ssh|git)://(?:git@)?github\.com/)"
    r"askscio/scio(?:\.git)?/?"
)


def git(repo, *args, check=True):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def discover_repos(roots=None):
    """Check standard Mac/Coder roots and their immediate children, not caches."""
    if roots is None:
        home = pathlib.Path.home()
        roots = [home, home / "workspace", pathlib.Path("/home/workspace"),
                 pathlib.Path("/workspace"), pathlib.Path("/workspaces")]
    candidates = [pathlib.Path.cwd()]
    for root in roots:
        if root.is_dir():
            candidates.append(root)
            candidates.extend(path for path in root.iterdir() if path.is_dir())
    return candidates


def configure(repos):
    seen = set()
    configured = 0
    for repo in repos:
        # A worktree has a .git file rather than a directory. Requiring this
        # marker also prevents mistaking every subdirectory for another clone.
        repo = pathlib.Path(repo)
        if not (repo / ".git").exists():
            continue
        origin = git(repo, "config", "--get", "remote.origin.url", check=False)
        if origin.returncode or not SCIO_ORIGIN.fullmatch(origin.stdout.strip()):
            continue
        common = git(repo, "rev-parse", "--git-common-dir").stdout.strip()
        common = (repo / common).resolve()
        if common in seen:
            continue
        seen.add(common)
        existing = git(repo, "config", "--local", "--get-all",
                       "remote.origin.fetch", check=False)
        if existing.returncode not in (0, 1):
            existing.check_returncode()
        if existing.stdout.splitlines() != FETCH_REFSPECS:
            # Fetch refspecs are multi-valued and repository-local; a global
            # config include cannot override the clone's existing wildcard.
            git(repo, "config", "--local", "--replace-all", "remote.origin.fetch",
                FETCH_REFSPECS[0])
            for refspec in FETCH_REFSPECS[1:]:
                git(repo, "config", "--local", "--add", "remote.origin.fetch", refspec)
            print(f"Configured Scio fetch in {repo}: master, james-*, release-*")
        else:
            print(f"Scio fetch already configured in {repo}")
        configured += 1
    if not configured:
        print("No Scio clones found; rerun install.sh after cloning Scio.")


if __name__ == "__main__":
    configure(sys.argv[1:] or discover_repos())
