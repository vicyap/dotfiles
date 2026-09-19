#!/usr/bin/env python3
"""Exercise skill convergence with the real skills CLI in temporary homes."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class SkillConvergenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotfiles-skills-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.dotfiles = self.root / "dotfiles"
        self.dotfiles.mkdir()
        self.shared = self.home / ".agents/skills"
        self.claude = self.home / ".claude/skills"
        self.codex = self.home / ".codex/skills"
        self.ownership = self.home / ".agents/.dotfiles-skills.txt"
        self.declarations = self.dotfiles / "agent-skills.txt"
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            CODEX_HOME=str(self.home / ".codex"),
            CLAUDE_CONFIG_DIR=str(self.home / ".claude"),
            XDG_STATE_HOME=str(self.home / ".local/state"),
            XDG_CONFIG_HOME=str(self.home / ".config"),
            npm_config_cache=str(Path.home() / ".npm"),
            DISABLE_TELEMETRY="1",
        )
        for name in ("keep", "remove-me", "unlisted"):
            self.write_skill(self.dotfiles / "skills" / name, name, "first version")

    def write_skill(self, path, name, body):
        path.mkdir(parents=True, exist_ok=True)
        (path / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: Test fixture\n---\n{body}\n"
        )

    def sync(self, success=True):
        result = subprocess.run(
            [
                sys.executable,
                str(REPO / "lib/sync-agent-skills.py"),
                str(self.dotfiles),
            ],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_refresh_prune_and_unmanaged_preservation(self):
        for directory in (self.shared, self.claude, self.codex):
            self.write_skill(directory / "manual", "manual", "unmanaged")
        self.write_skill(self.codex / ".system/builtin", "builtin", "built-in")
        self.claude.mkdir(parents=True, exist_ok=True)
        (self.claude / "unmanaged-broken").symlink_to(self.root / "absent")

        self.declarations.write_text("./skills keep remove-me\n")
        self.sync()
        self.assertEqual(self.ownership.read_text(), "keep\nremove-me\n")
        self.assertFalse((self.shared / "unlisted").exists())
        self.assertTrue((self.claude / "keep").samefile(self.shared / "keep"))
        first = (self.shared / "keep/SKILL.md").read_bytes()
        self.sync()
        self.assertEqual((self.shared / "keep/SKILL.md").read_bytes(), first)
        self.assertEqual(self.ownership.read_text(), "keep\nremove-me\n")

        # Refresh repairs contents and removes obsolete files and native copies.
        (self.shared / "keep/stale.txt").write_text("drift")
        self.write_skill(self.codex / "keep", "keep", "obsolete native copy")
        self.write_skill(self.dotfiles / "skills/keep", "keep", "second version")
        self.declarations.write_text("./skills keep\n")
        lock = self.home / ".local/state/skills/.skill-lock.json"
        lock.parent.mkdir(parents=True)
        lock.write_text(
            json.dumps(
                {
                    "version": 3,
                    "skills": {"keep": {}, "remove-me": {}, "manual": {}},
                    "dismissed": {"notice": True},
                }
            )
        )
        self.sync()
        self.assertIn("second version", (self.shared / "keep/SKILL.md").read_text())
        self.assertFalse((self.shared / "keep/stale.txt").exists())
        self.assertFalse((self.codex / "keep").exists())
        for directory in (self.shared, self.claude, self.codex):
            self.assertFalse((directory / "remove-me").exists())
            self.assertTrue((directory / "manual/SKILL.md").is_file())
        self.assertTrue((self.codex / ".system/builtin/SKILL.md").is_file())
        self.assertTrue((self.claude / "unmanaged-broken").is_symlink())
        self.assertEqual(
            json.loads(lock.read_text()),
            {"version": 3, "skills": {"manual": {}}, "dismissed": {"notice": True}},
        )

        # An empty declaration removes the final managed skill, not manual ones.
        self.declarations.write_text("# No managed skills\n")
        self.sync()
        self.sync()
        self.assertEqual(self.ownership.read_text(), "")
        self.assertFalse((self.shared / "keep").exists())
        self.assertFalse((self.claude / "keep").is_symlink())
        self.assertTrue((self.claude / "manual/SKILL.md").is_file())

    def test_failed_install_does_not_prune_and_can_be_retried(self):
        self.declarations.write_text("./skills remove-me\n")
        self.sync()
        self.declarations.write_text("./skills keep\n./missing-source missing\n")
        self.sync(success=False)
        self.assertTrue((self.shared / "remove-me/SKILL.md").is_file())
        self.assertTrue((self.shared / "keep/SKILL.md").is_file())
        self.assertIn("keep", self.ownership.read_text().splitlines())
        self.assertNotIn("missing", self.ownership.read_text().splitlines())
        self.declarations.write_text("./skills keep\n")
        self.sync()
        self.assertFalse((self.shared / "remove-me").exists())
        self.assertEqual(self.ownership.read_text(), "keep\n")

    def test_legacy_ownership_and_external_symlink_target(self):
        external = self.root / "external"
        self.write_skill(external, "legacy", "must survive")
        for directory in (self.shared, self.claude, self.codex):
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "legacy").symlink_to(external, target_is_directory=True)
        self.ownership.write_text("legacy\n")
        self.declarations.write_text("")
        self.sync()
        self.assertTrue((external / "SKILL.md").is_file())
        for directory in (self.shared, self.claude, self.codex):
            self.assertFalse((directory / "legacy").is_symlink())

    def test_invalid_declaration_does_not_mutate_installation(self):
        self.declarations.write_text("./skills keep\n")
        self.sync()
        before = self.ownership.read_text()
        for declaration in (
            "./skills ../escape\n",
            "./skills --all\n",
            "./skills .system\n",
            "./skills keep keep\n",
            "./skills\n",
            "./skills keep\n./skills keep\n",
        ):
            self.declarations.write_text(declaration)
            self.sync(success=False)
            self.assertEqual(self.ownership.read_text(), before)
            self.assertTrue((self.shared / "keep/SKILL.md").is_file())


if __name__ == "__main__":
    unittest.main()
