"""Filesystem locations.

Everything derived from the account or from browser history is written under
the state dir, outside the public dotfiles repo. Nothing in this package
writes into the repo except the user editing `kagi.toml` by hand.
"""

from __future__ import annotations

import os
from pathlib import Path

REPO_CONFIG = Path(__file__).resolve().parents[2] / "kagi.toml"


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME")
    root = Path(base) if base else Path.home() / ".local" / "state"
    path = root / "kagi"
    path.mkdir(parents=True, exist_ok=True)
    return path


def exports_dir() -> Path:
    path = state_dir() / "exports"
    path.mkdir(exist_ok=True)
    return path


def brave_history(profile: str = "Default") -> Path:
    return (
        Path.home()
        / "Library"
        / "Application Support"
        / "BraveSoftware"
        / "Brave-Browser"
        / profile
        / "History"
    )
