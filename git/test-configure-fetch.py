#!/usr/bin/env python3
"""Offline integration tests: python3 git/test-configure-fetch.py."""

import importlib.util
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "configure_fetch", pathlib.Path(__file__).with_name("configure-fetch.py")
)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class ConfigureFetchTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.env = mock.patch.dict(os.environ, {
            "HOME": str(self.root),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com",
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        self.repo = self.root / "scio"
        self.git(self.root, "init", "--initial-branch=master", str(self.repo))
        self.git(self.repo, "commit", "--allow-empty", "-m", "initial")
        self.git(self.repo, "remote", "add", "origin", "https://github.com/askscio/scio")

    def git(self, repo, *args):
        return subprocess.run(["git", "-C", str(repo), *args], check=True,
                              capture_output=True, text=True).stdout.strip()

    def refspecs(self, repo=None):
        return self.git(repo or self.repo, "config", "--local", "--get-all",
                        "remote.origin.fetch").splitlines()

    def test_replaces_wildcard_and_is_idempotent(self):
        setup.configure([self.repo])
        self.assertEqual(self.refspecs(), setup.FETCH_REFSPECS)
        config = self.repo / ".git/config"
        before = config.read_bytes()
        setup.configure([self.repo])
        self.assertEqual(config.read_bytes(), before)

    def test_supports_mac_and_coder_origin_forms(self):
        for origin in ("git@github.com:askscio/scio.git",
                       "ssh://git@github.com/askscio/scio.git",
                       "https://github.com/askscio/scio.git",
                       "https://github.com/askscio/scio/"):
            with self.subTest(origin=origin):
                self.git(self.repo, "remote", "set-url", "origin", origin)
                setup.configure([self.repo])
                self.assertEqual(self.refspecs(), setup.FETCH_REFSPECS)

    def test_unrelated_origins_and_non_repos_are_unchanged(self):
        for origin in ("git@github.com:james-scio/dotfiles.git",
                       "https://github.com/askscio/scio-other",
                       "https://example.com/askscio/scio",
                       "https://github.com.evil/askscio/scio"):
            with self.subTest(origin=origin):
                self.git(self.repo, "remote", "set-url", "origin", origin)
                before = (self.repo / ".git/config").read_bytes()
                setup.configure([self.repo, self.root / "missing", self.root])
                self.assertEqual((self.repo / ".git/config").read_bytes(), before)

    def test_preserves_branches_refs_worktree_and_other_settings(self):
        self.git(self.repo, "branch", "someone/keep")
        self.git(self.repo, "update-ref", "refs/remotes/origin/someone/keep", "HEAD")
        self.git(self.repo, "config", "remote.origin.prune", "false")
        dirty = self.repo / "untracked.txt"
        dirty.write_text("keep me\n")
        refs = self.git(self.repo, "show-ref")
        status = self.git(self.repo, "status", "--porcelain")
        setup.configure([self.repo])
        self.assertEqual(self.git(self.repo, "show-ref"), refs)
        self.assertEqual(self.git(self.repo, "status", "--porcelain"), status)
        self.assertEqual(dirty.read_text(), "keep me\n")
        self.assertEqual(self.git(self.repo, "config", "remote.origin.prune"), "false")

    def test_worktrees_share_one_configuration(self):
        worktree = self.root / "worktree"
        self.git(self.repo, "worktree", "add", "-b", "james-worktree", str(worktree))
        setup.configure([worktree, self.repo])
        self.assertEqual(self.refspecs(), setup.FETCH_REFSPECS)
        self.assertEqual(self.refspecs(worktree), setup.FETCH_REFSPECS)

    def test_discovery_finds_home_and_workspace_without_recursing(self):
        workspace = self.root / "workspace"
        workspace.mkdir()
        worktree = workspace / "deploy"
        self.git(self.repo, "worktree", "add", "-b", "james-deploy", str(worktree))
        # Do not inspect/configure the machine's actual Coder repositories.
        with mock.patch.object(pathlib.Path, "cwd", return_value=self.root):
            candidates = setup.discover_repos(roots=[self.root, workspace])
        self.assertIn(self.repo, candidates)
        self.assertIn(worktree, candidates)
        self.assertNotIn(self.repo / ".git", candidates)
        setup.configure(candidates)
        self.assertEqual(self.refspecs(), setup.FETCH_REFSPECS)

    def test_actual_fetch_only_updates_selected_branches(self):
        remote = self.root / "remote.git"
        self.git(self.root, "init", "--bare", str(remote))
        self.git(self.repo, "push", str(remote), "master")
        setup.configure([self.repo])
        for branch in ("james-feature", "release-test", "someone/unwanted"):
            self.git(self.repo, "push", str(remote), f"HEAD:refs/heads/{branch}")
        # Route the recognized GitHub URL to a local bare fixture: no network.
        self.git(self.repo, "-c", f"url.{remote.as_uri()}.insteadOf=https://github.com/askscio/scio",
                 "fetch", "origin")
        refs = self.git(self.repo, "for-each-ref", "--format=%(refname)",
                        "refs/remotes/origin").splitlines()
        # Recent Git versions also create the symbolic origin/HEAD on fetch.
        refs = [ref for ref in refs if ref != "refs/remotes/origin/HEAD"]
        self.assertEqual(sorted(refs), sorted([
            "refs/remotes/origin/master", "refs/remotes/origin/james-feature",
            "refs/remotes/origin/release-test",
        ]))


if __name__ == "__main__":
    unittest.main()
