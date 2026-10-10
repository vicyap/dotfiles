"""Mine local usage into a proposed config fragment.

Sources are Brave's History sqlite and any Kagi Assistant thread exports the
user has dropped into the state dir's `exports/`. Output is a report and a TOML
fragment in the state dir; this module never edits `kagi.toml`.
"""

from __future__ import annotations

import json
import shutil
import sqlite3
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from kagi_config.paths import exports_dir, state_dir

KAGI_QUERY_PATHS = {"/search": "search", "/assistant": "assistant"}
DEFAULT_MIN_CLICKS = 3


@dataclass
class Query:
    kind: str
    text: str
    visit_id: int
    clicked: list[str] = field(default_factory=list)


@dataclass
class Usage:
    queries: list[Query]
    export_notes: list[str] = field(default_factory=list)

    def clicked_domains(self) -> Counter[str]:
        return Counter(domain for q in self.queries for domain in q.clicked)

    def raise_candidates(self, min_clicks: int) -> list[tuple[str, int]]:
        counts = self.clicked_domains()
        return sorted(
            ((d, n) for d, n in counts.items() if n >= min_clicks),
            key=lambda item: (-item[1], item[0]),
        )


def mine(history: Path, *, min_clicks: int = DEFAULT_MIN_CLICKS) -> tuple[Path, Path]:
    """Mine `history` and write report + proposal into the state dir. Returns both paths."""
    usage = read_history(history)
    usage.export_notes = read_exports(exports_dir())
    stamp = datetime.now(tz=UTC).strftime("%Y%m%dT%H%M%SZ")
    out = state_dir()
    report = out / f"report-{stamp}.md"
    proposal = out / f"proposal-{stamp}.toml"
    report.write_text(render_report(usage, min_clicks))
    proposal.write_text(render_proposal(usage, min_clicks))
    return report, proposal


def read_history(history: Path) -> Usage:
    """Copy the (possibly locked) sqlite into the state dir and read Kagi queries + clicks."""
    if not history.exists():
        msg = f"history database not found: {history}"
        raise FileNotFoundError(msg)
    snapshot = state_dir() / "brave-history-snapshot.sqlite"
    shutil.copyfile(history, snapshot)
    con = sqlite3.connect(f"file:{snapshot}?mode=ro", uri=True)
    try:
        return _extract(con)
    finally:
        con.close()


def _extract(con: sqlite3.Connection) -> Usage:
    rows = con.execute(
        "SELECT v.id, v.from_visit, u.url FROM visits v JOIN urls u ON u.id = v.url ORDER BY v.id",
    ).fetchall()
    url_by_visit = {visit_id: url for visit_id, _, url in rows}
    children: dict[int, list[int]] = defaultdict(list)
    for visit_id, from_visit, _ in rows:
        if from_visit:
            children[from_visit].append(visit_id)

    queries: list[Query] = []
    for visit_id, _, url in rows:
        parsed = _parse_kagi_query(url)
        if parsed is None:
            continue
        kind, text = parsed
        clicked = [
            domain
            for child in children.get(visit_id, [])
            if (domain := _domain(url_by_visit[child])) and domain != "kagi.com"
        ]
        queries.append(Query(kind=kind, text=text, visit_id=visit_id, clicked=clicked))
    return Usage(queries=queries)


def _parse_kagi_query(url: str) -> tuple[str, str] | None:
    parts = urlsplit(url)
    if parts.netloc != "kagi.com" or parts.path not in KAGI_QUERY_PATHS:
        return None
    text = parse_qs(parts.query).get("q", [""])[0].strip()
    if not text:
        return None
    return KAGI_QUERY_PATHS[parts.path], text


def _domain(url: str) -> str:
    host = urlsplit(url).netloc.lower()
    return host.removeprefix("www.")


def read_exports(folder: Path) -> list[str]:
    """Best-effort look at Assistant thread exports. Format is unverified; report what is there."""
    notes: list[str] = []
    files = sorted(p for p in folder.iterdir() if p.is_file()) if folder.exists() else []
    if not files:
        return [f"no Assistant exports found in {folder}"]
    for path in files:
        if path.suffix == ".json":
            try:
                data = json.loads(path.read_text())
            except json.JSONDecodeError:
                notes.append(f"{path.name}: not valid JSON, skipped")
                continue
            notes.append(
                f"{path.name}: JSON with top-level {type(data).__name__}, {len(data)} items"
            )
        elif path.suffix in {".md", ".txt"}:
            notes.append(f"{path.name}: {len(path.read_text().splitlines())} lines of text")
        else:
            notes.append(f"{path.name}: unrecognized format, skipped")
    return notes


def render_report(usage: Usage, min_clicks: int) -> str:
    top_queries = Counter(q.text for q in usage.queries).most_common(30)
    lines = ["# Kagi usage report", ""]
    lines.append(
        f"Queries: {len(usage.queries)} "
        f"({sum(q.kind == 'search' for q in usage.queries)} search, "
        f"{sum(q.kind == 'assistant' for q in usage.queries)} assistant)"
    )
    lines += ["", "## Top queries", ""]
    lines += [f"- {n}x {text}" for text, n in top_queries]
    lines += ["", "## Clicked domains", ""]
    lines += [f"- {n}x {domain}" for domain, n in usage.clicked_domains().most_common(40)]
    lines += ["", f"## Raise candidates (clicked >= {min_clicks} times)", ""]
    lines += [f"- {domain} ({n})" for domain, n in usage.raise_candidates(min_clicks)]
    lines += ["", "## Assistant exports", ""]
    lines += [f"- {note}" for note in usage.export_notes]
    return "\n".join(lines) + "\n"


def render_proposal(usage: Usage, min_clicks: int) -> str:
    candidates = usage.raise_candidates(min_clicks)
    lines = [
        "# Proposed additions from local usage. Review, then merge into kagi.toml by hand.",
        "# Domains already in kagi.toml are not filtered out here; plan will show no-ops.",
        "",
        "[ranked]",
        "raise = [",
    ]
    lines += [f'  "{domain}",  # clicked {n}x' for domain, n in candidates]
    lines.append("]")
    return "\n".join(lines) + "\n"
