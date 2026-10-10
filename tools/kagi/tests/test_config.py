from pathlib import Path

import pytest

from kagi_config import config


def write(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "kagi.toml"
    path.write_text(text)
    return path


def test_round_trip(tmp_path: Path) -> None:
    cfg = config.load(
        write(
            tmp_path,
            """
            [ranked]
            block = ["dev.to"]
            raise = ["simonwillison.net"]

            [builtin_lenses]
            enabled = ["forums"]

            [[lens]]
            name = "Eng"
            exclude_domains = ["medium.com"]
            exclude_keywords = ["tutorial"]

            [[assistant]]
            name = "Research"
            lens = "Eng"
            model = "ki_research"
            bang = "research"
            instructions = "be concrete"

            [[assistant]]
            name = "Forums"
            lens = "forums"
            model = "claude"
            bang = "forums2"
            instructions = "opinions"
            """,
        ),
    )
    assert cfg.ranked.by_domain() == {"dev.to": "block", "simonwillison.net": "raise"}
    assert cfg.lenses[0].name == "Eng"
    assert cfg.lenses[0].enabled is True
    assert cfg.lenses[0].include_domains == ()
    assert cfg.assistants[0].model == "ki_research"
    assert cfg.assistants[1].bang == "forums2"
    assert cfg.lens_names() == {"Eng", "forums"}


@pytest.mark.parametrize("field", ["model", "bang"])
def test_assistant_requires_model_and_bang(tmp_path: Path, field: str) -> None:
    lines = {"model": 'model = "ki_quick"', "bang": 'bang = "x1"'}
    del lines[field]
    body = "\n".join(lines.values())
    with pytest.raises(config.ConfigError, match=rf"assistant\[0\]\.{field}"):
        config.load(write(tmp_path, f'[[assistant]]\nname = "A"\ninstructions = "i"\n{body}\n'))


@pytest.mark.parametrize("bang", ["!x", "my bang", "Compare"])
def test_bang_shape(tmp_path: Path, bang: str) -> None:
    text = f'[[assistant]]\nname = "A"\ninstructions = "i"\nmodel = "m"\nbang = "{bang}"\n'
    with pytest.raises(config.ConfigError, match="bang"):
        config.load(write(tmp_path, text))


def test_seed_config_is_valid() -> None:
    cfg = config.load(Path(__file__).resolve().parents[1] / "kagi.toml")
    assert {lens.name for lens in cfg.lenses} == {"Product Search", "Engineering Blogs"}


@pytest.mark.parametrize(
    ("key", "count", "cap"),
    [
        ("include_domains", 11, 10),
        ("exclude_domains", 11, 10),
        ("include_keywords", 6, 5),
        ("exclude_keywords", 6, 5),
    ],
)
def test_lens_caps(tmp_path: Path, key: str, count: int, cap: int) -> None:
    items = ", ".join(f'"x{i}"' for i in range(count))
    with pytest.raises(config.ConfigError, match=f"lens\\[0\\].{key}.*at most {cap}"):
        config.load(write(tmp_path, f'[[lens]]\nname = "L"\n{key} = [{items}]\n'))


def test_domain_in_two_rank_lists(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match="ranked: 'a.com'"):
        config.load(write(tmp_path, '[ranked]\nblock = ["a.com"]\nraise = ["a.com"]\n'))


def test_duplicate_within_list(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match="ranked.block: duplicate"):
        config.load(write(tmp_path, '[ranked]\nblock = ["a.com", "a.com"]\n'))


def test_unknown_lens_reference(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match="assistant.lens: 'nope'"):
        config.load(
            write(
                tmp_path,
                '[[assistant]]\nname = "A"\ninstructions = "i"\n'
                'model = "m"\nbang = "a"\nlens = "nope"\n',
            ),
        )


def test_lens_requires_name(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match="lens\\[0\\].name"):
        config.load(write(tmp_path, '[[lens]]\nexclude_domains = ["a.com"]\n'))


def test_duplicate_lens_names(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match="lens.name: duplicate"):
        config.load(write(tmp_path, '[[lens]]\nname = "L"\n[[lens]]\nname = "L"\n'))


@pytest.mark.parametrize(
    "bad", ["nytimes.com/wirecutter", "https://a.com", "a.com:443", "localhost"]
)
def test_domain_shape(tmp_path: Path, bad: str) -> None:
    with pytest.raises(config.ConfigError, match="not a bare domain"):
        config.load(write(tmp_path, f'[ranked]\nraise = ["{bad}"]\n'))


def test_lens_domain_shape(tmp_path: Path) -> None:
    with pytest.raises(config.ConfigError, match=r"lens\[0\].exclude_domains: .*not a bare domain"):
        config.load(write(tmp_path, '[[lens]]\nname = "L"\nexclude_domains = ["a.com/x"]\n'))
