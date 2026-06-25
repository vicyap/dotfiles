#!/usr/bin/env python3
"""Merge Codex's generated config.toml, preserving runtime-written state.

Codex writes runtime state into ~/.codex/config.toml that the dotfiles do not
manage: `[projects]` trust entries, `[hooks.state]` approval hashes, `[tui]`
nux flags, `[notice]` migration records, and top-level scalars such as
`service_tier`. A plain `rm + cat base` regen wipes all of it (forcing hook
re-approval on every `dotfiles pull`).

This re-emits the managed files (base, then optional local) verbatim, then
appends any top-level scalar keys and tables the managed files do NOT define —
keeping scalars in the pre-table region so the result stays valid TOML.

Usage: merge-codex-config.py BASE LOCAL OLD  > merged.toml
  BASE  managed base config (required)
  LOCAL machine-local additions (may not exist)
  OLD   the previous generated config.toml to harvest runtime state from (may
        not exist, e.g. first run)

Comments/blanks above preserved runtime scalars are dropped (rare; runtime
scalars are written without leading comments); comments inside preserved tables
are kept. Only the standard library is used (tomllib not required — this is a
structural line-level merge that preserves exact formatting of kept sections).
"""
import re
import sys

# First dotted component of a table header: [foo], [[foo]], [foo.bar."baz"].
HDR = re.compile(r"^\s*\[\[?\s*([A-Za-z0-9_-]+)")
# A top-level scalar assignment: `key = value` (Codex top-level keys are bare).
SCALAR = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=")


def parse(path):
    """Split a TOML file into (preamble_lines, [{top, lines}]) blocks.

    preamble = lines before the first table header. Each block is one table
    header line plus the lines up to the next header. Missing file -> empty.
    """
    preamble = []
    blocks = []
    cur = None
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
    except OSError:
        return preamble, blocks
    for line in lines:
        match = HDR.match(line)
        if match:
            cur = {"top": match.group(1), "lines": [line]}
            blocks.append(cur)
        elif cur is not None:
            cur["lines"].append(line)
        else:
            preamble.append(line)
    return preamble, blocks


def scalar_key(line):
    match = SCALAR.match(line)
    return match.group(1) if match else None


def main():
    if len(sys.argv) != 4:
        sys.stderr.write("usage: merge-codex-config.py BASE LOCAL OLD\n")
        return 2
    base, local, old = sys.argv[1], sys.argv[2], sys.argv[3]

    base_pre, base_blocks = parse(base)
    local_pre, local_blocks = parse(local)
    old_pre, old_blocks = parse(old)

    base_scalar_keys = {k for k in map(scalar_key, base_pre) if k}
    local_scalar_keys = {k for k in map(scalar_key, local_pre) if k}
    managed_scalar_keys = base_scalar_keys | local_scalar_keys
    managed_tops = {b["top"] for b in base_blocks} | {b["top"] for b in local_blocks}

    out = []
    # Managed top-level scalars (base first, then local additions, deduped).
    out.extend(base_pre)
    for line in local_pre:
        key = scalar_key(line)
        if key is None or key not in base_scalar_keys:
            out.append(line)
    # Preserved runtime scalars (e.g. service_tier) — must precede any table.
    preserved_scalars = [
        line
        for line in old_pre
        if (k := scalar_key(line)) and k not in managed_scalar_keys
    ]
    out.extend(preserved_scalars)
    if out and not out[-1].endswith("\n"):
        out.append("\n")

    # Managed tables, then runtime tables the managed files don't define.
    for block in base_blocks:
        out.extend(block["lines"])
    for block in local_blocks:
        out.extend(block["lines"])
    preserved_blocks = [b for b in old_blocks if b["top"] not in managed_tops]
    if preserved_blocks:
        out.append(
            "\n# --- preserved runtime state "
            "(projects/hooks/tui/notice; not in base/local) ---\n"
        )
        for block in preserved_blocks:
            out.extend(block["lines"])

    sys.stdout.write("".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
