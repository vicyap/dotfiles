#!/usr/bin/env python3
"""Refresh declared user skills for Claude Code and Codex, then prune owned removals.

Usage: sync-agent-skills.py DOTFILES_DIR

agent-skills.txt declares sources and skill names. The existing
~/.agents/.dotfiles-skills.txt records ownership; unrecorded skills are untouched.
Failed installs retain ownership of partial work and never trigger pruning.
"""

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def skill_names(names):
    for name in names:
        if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", name):
            raise ValueError(f"Invalid skill name: {name!r}")
    return set(names)


def remove(path):
    if path.is_symlink():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def record_ownership(path, names):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text("".join(f"{name}\n" for name in sorted(names)))
    temporary.replace(path)


def sync(dotfiles):
    packages = []
    desired = set()
    local_names = set()
    for line in (dotfiles / "agent-skills.txt").read_text().splitlines():
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        source, *names = fields
        if not names:
            raise ValueError(f"No skills listed for {source}")
        selected = skill_names(names)
        if len(selected) != len(names) or desired & selected:
            raise ValueError(f"Duplicate skill names in {source}")
        if source.startswith("./"):
            source = str(dotfiles / source)
            local_names.update(selected)
        packages.append((source, names))
        desired.update(selected)

    home = Path.home()
    shared = home / ".agents/skills"
    claude = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(home / ".claude"))) / "skills"
    codex = Path(os.environ.get("CODEX_HOME", str(home / ".codex"))) / "skills"
    ownership = home / ".agents/.dotfiles-skills.txt"
    previous = (
        skill_names(ownership.read_text().splitlines()) if ownership.exists() else set()
    )

    if packages and not shutil.which("npx"):
        raise RuntimeError("npx is required to sync agent skills")

    owned = previous.copy()
    for source, names in packages:
        result = subprocess.run(
            [
                "npx",
                "--yes",
                "skills",
                "add",
                source,
                "--global",
                "--agent",
                "claude-code",
                "codex",
                "--skill",
                *names,
                "--yes",
                "--json",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        installed = json.loads(result.stdout or "[]")
        installed_names = {
            item.get("name") for item in installed if item.get("status") == "installed"
        }
        # Keep ownership of completed installs even if a later group fails.
        owned.update(installed_names & set(names))
        record_ownership(ownership, owned)
        if result.returncode:
            raise RuntimeError(
                f"Skill install failed for {source}:\n{result.stderr}\n{result.stdout}"
            )
        if installed_names != set(names):
            raise RuntimeError(
                f"Incomplete skill install for {source}: {result.stdout}"
            )
        for name in names:
            if (
                not (shared / name / "SKILL.md").is_file()
                or not (claude / name / "SKILL.md").is_file()
            ):
                raise RuntimeError(
                    f"Skill {name} is missing from the shared or Claude skill directory"
                )
        print(f"  Refreshed {source}: {', '.join(names)}", flush=True)

    stale = previous - desired
    for name in sorted(stale):
        for directory in (claude, codex, shared):
            remove(directory / name)
        print(f"  Removed {name} (no longer declared)", flush=True)

    # Codex reads the canonical shared directory. Retire native copies of
    # declared skills so an older copy cannot shadow the refreshed version.
    for name in desired:
        if codex.resolve() != shared.resolve():
            remove(codex / name)

    state_home = os.environ.get("XDG_STATE_HOME")
    lock_path = (
        Path(state_home) / "skills/.skill-lock.json"
        if state_home
        else home / ".agents/.skill-lock.json"
    )
    if lock_path.exists():
        lock = json.loads(lock_path.read_text())
        for name in stale | local_names:
            lock.get("skills", {}).pop(name, None)
        lock_path.write_text(json.dumps(lock, indent=2) + "\n")
    record_ownership(ownership, desired)
    print(
        f"  Synced {len(desired)} managed skills for Claude Code and Codex", flush=True
    )


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("usage: sync-agent-skills.py DOTFILES_DIR")
        sync(Path(sys.argv[1]).resolve())
    except (OSError, ValueError, RuntimeError) as error:
        sys.exit(str(error))
