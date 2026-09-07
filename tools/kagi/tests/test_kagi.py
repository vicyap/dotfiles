from kagi_config.config import Assistant, Lens
from kagi_config.kagi import assistant_json, lens_form, parse_assistant, parse_lens


def test_lens_form_round_trips_through_the_settings_form() -> None:
    lens = Lens(
        name="Product Search",
        exclude_domains=("a.com", "b.org"),
        exclude_keywords=("top 10", "buyer's guide"),
        region="us",
        enabled=False,
    )
    form = lens_form(lens)
    assert form["included_sites"] == ""
    assert form["excluded_sites"] == "a.com, b.org"
    assert form["search_region"] == "us"
    assert parse_lens(form | {"id": "33014"}, enabled=False) == lens


def test_parse_lens_defaults() -> None:
    lens = parse_lens({"name": "X", "search_region": "no_region"}, enabled=True)
    assert lens == Lens(name="X")


def test_assistant_json_round_trips_through_the_api() -> None:
    assistant = Assistant(
        name="Product Compare",
        instructions="compare",
        model="ki_research",
        bang="compare",
        lens="Product Search",
        internet=True,
        personalized=False,
    )
    body = assistant_json(assistant, {"Product Search": "33014", "Forums": "1"})
    assert body == {
        "name": "Product Compare",
        "llm_id": "ki_research",
        "instructions": "compare",
        "internet_access": True,
        "personalizations": False,
        "lens_id": "33014",
        "bang_trigger": "compare",
    }
    raw = body | {"uuid": "u", "created_at": "t", "retired": False}
    assert parse_assistant(raw, {"33014": "Product Search"}) == assistant


def test_assistant_without_lens() -> None:
    assistant = Assistant(name="A", instructions="i", model="m", bang="a")
    assert assistant_json(assistant, {})["lens_id"] is None
    assert parse_assistant(assistant_json(assistant, {}), {}) == assistant
