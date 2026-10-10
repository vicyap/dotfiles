import sqlite3
from pathlib import Path

import pytest

from kagi_config import mine


@pytest.fixture
def state_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    return tmp_path / "state" / "kagi"


def build_history(path: Path) -> None:
    con = sqlite3.connect(path)
    con.executescript(
        """
        CREATE TABLE urls (id INTEGER PRIMARY KEY, url TEXT, title TEXT);
        CREATE TABLE visits (id INTEGER PRIMARY KEY, url INTEGER, from_visit INTEGER);
        """
    )
    urls = [
        (1, "https://kagi.com/search?q=hybrid+mattress+review"),
        (2, "https://www.reddit.com/r/Mattress/comments/abc"),
        (3, "https://www.nytimes.com/wirecutter/reviews/best-mattress/"),
        (4, "https://kagi.com/assistant?q=agentic+codebases"),
        (5, "https://simonwillison.net/2026/agents/"),
        (6, "https://kagi.com/search?q=hybrid+mattress+review"),
        (7, "https://kagi.com/settings/lenses"),
        (8, "https://example.org/unrelated"),
    ]
    con.executemany("INSERT INTO urls (id, url, title) VALUES (?, ?, '')", urls)
    visits = [
        (10, 1, 0),
        (11, 2, 10),
        (12, 3, 10),
        (13, 4, 0),
        (14, 5, 13),
        (15, 6, 0),
        (16, 2, 15),
        (17, 7, 15),
        (18, 8, 0),
    ]
    con.executemany("INSERT INTO visits (id, url, from_visit) VALUES (?, ?, ?)", visits)
    con.commit()
    con.close()


def test_read_history_extracts_queries_and_clicks(tmp_path: Path, state_home: Path) -> None:
    history = tmp_path / "History"
    build_history(history)
    usage = mine.read_history(history)
    assert [(q.kind, q.text) for q in usage.queries] == [
        ("search", "hybrid mattress review"),
        ("assistant", "agentic codebases"),
        ("search", "hybrid mattress review"),
    ]
    assert usage.queries[0].clicked == ["reddit.com", "nytimes.com"]
    assert usage.queries[2].clicked == ["reddit.com"]
    assert usage.clicked_domains()["reddit.com"] == 2
    assert usage.raise_candidates(2) == [("reddit.com", 2)]
    assert (state_home / "brave-history-snapshot.sqlite").exists()


def test_mine_writes_report_and_proposal_outside_repo(tmp_path: Path, state_home: Path) -> None:
    history = tmp_path / "History"
    build_history(history)
    report, proposal = mine.mine(history, min_clicks=2)
    assert report.parent == state_home
    assert proposal.parent == state_home
    assert "reddit.com" in proposal.read_text()
    assert "nytimes.com" not in proposal.read_text()
    assert "no Assistant exports found" in report.read_text()


def test_missing_history(tmp_path: Path, state_home: Path) -> None:
    with pytest.raises(FileNotFoundError):
        mine.read_history(tmp_path / "nope")


def test_read_exports_notes_formats(tmp_path: Path) -> None:
    (tmp_path / "a.json").write_text("[1, 2]")
    (tmp_path / "b.md").write_text("x\ny\n")
    (tmp_path / "c.bin").write_bytes(b"\x00")
    notes = mine.read_exports(tmp_path)
    assert notes == [
        "a.json: JSON with top-level list, 2 items",
        "b.md: 2 lines of text",
        "c.bin: unrecognized format, skipped",
    ]
