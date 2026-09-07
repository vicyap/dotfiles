"""Diff live account state against the config, Terraform-style.

`plan()` is pure: it never touches the browser. The config is the full truth,
so any live resource the config does not declare becomes a delete.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import TYPE_CHECKING

from kagi_config.config import Assistant, ConfigError, Lens

if TYPE_CHECKING:
    from kagi_config.config import Config


class Resource(StrEnum):
    RANKED = "ranked"
    LENS = "lens"
    BUILTIN_LENS = "builtin_lens"
    ASSISTANT = "assistant"


class Op(StrEnum):
    CREATE = "+"
    UPDATE = "~"
    DELETE = "-"


@dataclass(frozen=True)
class Change:
    op: Op
    resource: Resource
    key: str
    before: object = None
    after: object = None


@dataclass
class LiveState:
    """What `read` found on the account, in the same shape as the config.

    `builtin_lenses` holds the active built-ins; `builtin_available` every
    built-in Kagi offers. The id maps are what `apply` needs to address a
    resource; they cover every lens, built-in or custom.
    """

    ranked: dict[str, str] = field(default_factory=dict)
    lenses: dict[str, Lens] = field(default_factory=dict)
    builtin_lenses: set[str] = field(default_factory=set)
    builtin_available: set[str] = field(default_factory=set)
    assistants: dict[str, Assistant] = field(default_factory=dict)
    lens_ids: dict[str, str] = field(default_factory=dict)
    assistant_ids: dict[str, str] = field(default_factory=dict)


def plan(config: Config, live: LiveState) -> list[Change]:
    """Return the ordered changes that make `live` equal `config`.

    Raises ConfigError for a built-in lens name Kagi does not offer, since no
    change could create it.
    """
    unknown = sorted(set(config.builtin_lenses) - live.builtin_available)
    if unknown:
        offered = ", ".join(sorted(live.builtin_available))
        msg = f"builtin_lenses.enabled: {unknown} not offered by Kagi (offered: {offered})"
        raise ConfigError(msg)
    changes: list[Change] = []
    changes += _diff_map(
        Resource.RANKED,
        config.ranked.by_domain(),
        dict(live.ranked),
    )
    changes += _diff_map(
        Resource.LENS,
        {lens.name: lens for lens in config.lenses},
        dict(live.lenses),
    )
    changes += _diff_map(
        Resource.BUILTIN_LENS,
        dict.fromkeys(config.builtin_lenses, True),
        dict.fromkeys(sorted(live.builtin_lenses), True),
    )
    changes += _diff_map(
        Resource.ASSISTANT,
        {a.name: a for a in config.assistants},
        dict(live.assistants),
    )
    return changes


def _diff_map(resource: Resource, want: dict, have: dict) -> list[Change]:
    changes: list[Change] = []
    for key in sorted(set(want) | set(have)):
        in_want, in_have = key in want, key in have
        if in_want and not in_have:
            changes.append(Change(Op.CREATE, resource, key, after=want[key]))
        elif in_have and not in_want:
            changes.append(Change(Op.DELETE, resource, key, before=have[key]))
        elif want[key] != have[key]:
            changes.append(Change(Op.UPDATE, resource, key, before=have[key], after=want[key]))
    return changes


def render(changes: list[Change]) -> str:
    """Terraform-like summary: one line per change plus a count."""
    if not changes:
        return "No changes. Account matches kagi.toml."
    lines = [f"{c.op.value} {c.resource.value} {c.key}{_detail(c)}" for c in changes]
    counts = {op: sum(1 for c in changes if c.op is op) for op in Op}
    lines.append("")
    lines.append(
        f"Plan: {counts[Op.CREATE]} to add, {counts[Op.UPDATE]} to change, "
        f"{counts[Op.DELETE]} to destroy.",
    )
    return "\n".join(lines)


def _detail(change: Change) -> str:
    if change.resource is Resource.RANKED:
        if change.op is Op.UPDATE:
            return f" ({change.before} -> {change.after})"
        return f" ({change.after or change.before})"
    return ""
