"""Load and validate `kagi.toml`.

The config is the full truth for the account: anything not declared here is
deleted on `apply`. Validation enforces Kagi's documented lens caps at load
time so a bad file fails before any browser work starts.
"""

from __future__ import annotations

import re
import tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

RANK_ACTIONS = ("block", "lower", "raise", "pin")
LENS_DOMAIN_CAP = 10
LENS_KEYWORD_CAP = 5


class ConfigError(ValueError):
    """Raised when `kagi.toml` is malformed. The message names the field."""


@dataclass(frozen=True)
class Ranked:
    """Personalized results, keyed by the action Kagi applies to each domain."""

    block: tuple[str, ...] = ()
    lower: tuple[str, ...] = ()
    raise_: tuple[str, ...] = ()
    pin: tuple[str, ...] = ()

    def by_domain(self) -> dict[str, str]:
        """Map each domain to its action; the inverse of the per-action lists."""
        out: dict[str, str] = {}
        for action in RANK_ACTIONS:
            for domain in getattr(self, _attr(action)):
                out[domain] = action
        return out


@dataclass(frozen=True)
class Lens:
    """A custom lens. All list fields are optional; an exclude-only lens is valid."""

    name: str
    include_domains: tuple[str, ...] = ()
    exclude_domains: tuple[str, ...] = ()
    include_keywords: tuple[str, ...] = ()
    exclude_keywords: tuple[str, ...] = ()
    region: str | None = None
    enabled: bool = True


@dataclass(frozen=True)
class Assistant:
    """A Kagi custom assistant.

    `model` is a Kagi model id such as `ki_research`; the API rejects an empty
    one, so there is no "account default". `bang` is the trigger typed after
    `!` in the search box to start a thread with this assistant.
    """

    name: str
    instructions: str
    model: str
    bang: str
    lens: str | None = None
    internet: bool = True
    personalized: bool = True


@dataclass(frozen=True)
class Config:
    ranked: Ranked = field(default_factory=Ranked)
    lenses: tuple[Lens, ...] = ()
    # Built-in lenses by display name as shown on /settings/lenses ("Forums").
    builtin_lenses: tuple[str, ...] = ()
    assistants: tuple[Assistant, ...] = ()

    def lens_names(self) -> set[str]:
        return {lens.name for lens in self.lenses} | set(self.builtin_lenses)


def load(path: Path) -> Config:
    """Parse and validate the TOML file at `path`. Raises ConfigError."""
    with path.open("rb") as fh:
        raw = tomllib.load(fh)
    return from_dict(raw)


def from_dict(raw: dict[str, Any]) -> Config:
    ranked = _ranked(raw.get("ranked", {}))
    lenses = tuple(_lens(item, index) for index, item in enumerate(raw.get("lens", [])))
    builtin = tuple(_str_list(raw.get("builtin_lenses", {}), "enabled", "builtin_lenses.enabled"))
    assistants = tuple(
        _assistant(item, index) for index, item in enumerate(raw.get("assistant", []))
    )
    config = Config(ranked=ranked, lenses=lenses, builtin_lenses=builtin, assistants=assistants)
    _check_unique([lens.name for lens in lenses], "lens.name")
    _check_unique([a.name for a in assistants], "assistant.name")
    known = config.lens_names()
    for assistant in assistants:
        if assistant.lens is not None and assistant.lens not in known:
            msg = f"assistant.lens: {assistant.lens!r} is not a [[lens]] or builtin_lenses name"
            raise ConfigError(msg)
    return config


def _ranked(raw: dict[str, Any]) -> Ranked:
    lists = {
        action: tuple(_domain_list(raw, action, f"ranked.{action}")) for action in RANK_ACTIONS
    }
    seen: dict[str, str] = {}
    for action, domains in lists.items():
        for domain in domains:
            if domain in seen:
                msg = f"ranked: {domain!r} appears in both {seen[domain]!r} and {action!r}"
                raise ConfigError(msg)
            seen[domain] = action
    return Ranked(**{_attr(action): domains for action, domains in lists.items()})


def _lens(raw: dict[str, Any], index: int) -> Lens:
    where = f"lens[{index}]"
    name = _required_str(raw, "name", where)
    fields = {
        "include_domains": LENS_DOMAIN_CAP,
        "exclude_domains": LENS_DOMAIN_CAP,
        "include_keywords": LENS_KEYWORD_CAP,
        "exclude_keywords": LENS_KEYWORD_CAP,
    }
    values: dict[str, Any] = {}
    for key, cap in fields.items():
        items = _str_list(raw, key, f"{where}.{key}")
        if len(items) > cap:
            msg = f"{where}.{key}: {len(items)} entries, Kagi allows at most {cap}"
            raise ConfigError(msg)
        if key.endswith("_domains"):
            _check_domains(items, f"{where}.{key}")
        values[key] = tuple(items)
    region = raw.get("region")
    if region is not None and not isinstance(region, str):
        msg = f"{where}.region: must be a string"
        raise ConfigError(msg)
    return Lens(
        name=name,
        region=region,
        enabled=_bool(raw, "enabled", where, default=True),
        **values,
    )


def _assistant(raw: dict[str, Any], index: int) -> Assistant:
    where = f"assistant[{index}]"
    lens = raw.get("lens")
    if lens is not None and not isinstance(lens, str):
        msg = f"{where}.lens: must be a string"
        raise ConfigError(msg)
    bang = _required_str(raw, "bang", where)
    if not BANG_RE.match(bang):
        msg = f"{where}.bang: {bang!r} must be lowercase letters and digits, without the '!'"
        raise ConfigError(msg)
    return Assistant(
        name=_required_str(raw, "name", where),
        instructions=_required_str(raw, "instructions", where),
        model=_required_str(raw, "model", where),
        bang=bang,
        lens=lens,
        internet=_bool(raw, "internet", where, default=True),
        personalized=_bool(raw, "personalized", where, default=True),
    )


def _attr(action: str) -> str:
    # `raise` is a keyword, so the dataclass field is `raise_`.
    return "raise_" if action == "raise" else action


def _required_str(raw: dict[str, Any], key: str, where: str) -> str:
    value = raw.get(key)
    if not isinstance(value, str) or not value.strip():
        msg = f"{where}.{key}: required non-empty string"
        raise ConfigError(msg)
    return value


def _bool(raw: dict[str, Any], key: str, where: str, *, default: bool) -> bool:
    value = raw.get(key, default)
    if not isinstance(value, bool):
        msg = f"{where}.{key}: must be true or false"
        raise ConfigError(msg)
    return value


# Kagi ranks and filters whole hosts. A path such as "nytimes.com/wirecutter"
# would either be rejected at apply time or silently widen to the whole domain.
DOMAIN_RE = re.compile(r"^(?!-)[a-z0-9-]+(\.[a-z0-9-]+)+$")
BANG_RE = re.compile(r"^[a-z0-9]+$")


def _domain_list(raw: dict[str, Any], key: str, where: str) -> list[str]:
    domains = _str_list(raw, key, where)
    _check_domains(domains, where)
    return domains


def _check_domains(domains: list[str], where: str) -> None:
    for domain in domains:
        if not DOMAIN_RE.match(domain):
            msg = f"{where}: {domain!r} is not a bare domain (no scheme, path, or port)"
            raise ConfigError(msg)


def _str_list(raw: dict[str, Any], key: str, where: str) -> list[str]:
    value = raw.get(key, [])
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        msg = f"{where}: must be a list of strings"
        raise ConfigError(msg)
    _check_unique(value, where)
    return value


def _check_unique(values: list[str], where: str) -> None:
    seen: set[str] = set()
    for value in values:
        if value in seen:
            msg = f"{where}: duplicate entry {value!r}"
            raise ConfigError(msg)
        seen.add(value)
