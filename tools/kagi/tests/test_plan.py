import pytest

from kagi_config.config import Assistant, Config, ConfigError, Lens, Ranked
from kagi_config.plan import LiveState, Op, Resource, plan, render

BUILTINS = {"Forums", "News 360"}


def assistant(name: str, lens: str | None = None) -> Assistant:
    return Assistant(name=name, instructions="i", model="ki_quick", bang=name.lower(), lens=lens)


def test_empty_account_creates_everything() -> None:
    cfg = Config(
        ranked=Ranked(block=("dev.to",), raise_=("simonwillison.net",)),
        lenses=(Lens(name="Eng", exclude_domains=("medium.com",)),),
        builtin_lenses=("Forums",),
        assistants=(assistant("R", lens="Eng"),),
    )
    changes = plan(cfg, LiveState(builtin_available=BUILTINS))
    assert [(c.op, c.resource, c.key) for c in changes] == [
        (Op.CREATE, Resource.RANKED, "dev.to"),
        (Op.CREATE, Resource.RANKED, "simonwillison.net"),
        (Op.CREATE, Resource.LENS, "Eng"),
        (Op.CREATE, Resource.BUILTIN_LENS, "Forums"),
        (Op.CREATE, Resource.ASSISTANT, "R"),
    ]
    assert changes[0].after == "block"


def test_config_is_full_truth_deletes_extras() -> None:
    live = LiveState(
        ranked={"a.com": "block"},
        lenses={"Old": Lens(name="Old")},
        builtin_lenses={"News 360"},
        builtin_available=BUILTINS,
        assistants={"Gone": assistant("Gone")},
    )
    changes = plan(Config(), live)
    assert all(c.op is Op.DELETE for c in changes)
    assert {c.key for c in changes} == {"a.com", "Old", "News 360", "Gone"}


def test_update_when_action_or_fields_differ() -> None:
    cfg = Config(
        ranked=Ranked(raise_=("a.com",)),
        lenses=(Lens(name="Eng", exclude_keywords=("tutorial",)),),
    )
    live = LiveState(ranked={"a.com": "lower"}, lenses={"Eng": Lens(name="Eng")})
    changes = plan(cfg, live)
    assert [(c.op, c.key, c.before, c.after) for c in changes if c.resource is Resource.RANKED] == [
        (Op.UPDATE, "a.com", "lower", "raise"),
    ]
    assert [c.op for c in changes if c.resource is Resource.LENS] == [Op.UPDATE]


def test_no_changes_when_equal() -> None:
    lens = Lens(name="Eng")
    cfg = Config(lenses=(lens,), builtin_lenses=("Forums",), assistants=(assistant("R"),))
    live = LiveState(
        lenses={"Eng": lens},
        builtin_lenses={"Forums"},
        builtin_available=BUILTINS,
        assistants={"R": assistant("R")},
        lens_ids={"Eng": "1"},
        assistant_ids={"R": "uuid"},
    )
    assert plan(cfg, live) == []
    assert render([]) == "No changes. Account matches kagi.toml."


def test_unknown_builtin_is_an_error_not_a_create() -> None:
    cfg = Config(builtin_lenses=("forums",))
    with pytest.raises(
        ConfigError, match=r"\['forums'\] not offered by Kagi \(offered: Forums, News 360\)"
    ):
        plan(cfg, LiveState(builtin_available=BUILTINS))


def test_render_summary() -> None:
    cfg = Config(ranked=Ranked(block=("dev.to",)))
    out = render(plan(cfg, LiveState(ranked={"old.com": "pin"})))
    assert "+ ranked dev.to (block)" in out
    assert "- ranked old.com (pin)" in out
    assert out.endswith("Plan: 1 to add, 0 to change, 1 to destroy.")
